"""Sajag API. Run from backend/:  uvicorn app.main:app --reload"""

from __future__ import annotations

import asyncio
import json

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.concurrency import run_in_threadpool
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse, Response, StreamingResponse
from fastapi.staticfiles import StaticFiles
from pydantic import ValidationError

from . import catalog, gemma
from .agent import AgentRequest, AgentResponse, run_agent
from .analysis import UploadedAudio, UploadedImage, analyze
from .complaint import build_complaint, complaint_resources
from .petition import Complainant as PetitionComplainant
from .petition import DraftRequest, PetitionFields, draft_fields, render_pdf
from .config import (
    FRONTEND_DIST,
    MAX_AUDIO,
    MAX_AUDIO_BYTES,
    MAX_IMAGE_BYTES,
    MAX_IMAGES,
    MAX_TEXT_CHARS,
    MOCK_MODE,
)
from .schemas import AnalysisResponse, ComplaintRequest, ComplaintResponse, Stage

ALLOWED_IMAGE_TYPES = {"image/png", "image/jpeg", "image/webp"}

app = FastAPI(title="Sajag", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://127.0.0.1:5173"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/api/health")
def health() -> dict:
    return {"ok": True, "mock": MOCK_MODE}


@app.get("/api/patterns")
def get_patterns() -> list[dict]:
    return list(catalog.patterns().values())


@app.get("/api/resources")
def get_resources() -> list[dict]:
    return catalog.resources()


async def _read_uploads(
    text: str, images: list[UploadFile], audios: list[UploadFile]
) -> tuple[list[UploadedImage], list[UploadedAudio]]:
    if len(text) > MAX_TEXT_CHARS:
        raise HTTPException(413, f"Text is longer than {MAX_TEXT_CHARS} characters.")
    if len(images) > MAX_IMAGES:
        raise HTTPException(413, f"At most {MAX_IMAGES} images per check.")
    if len(audios) > MAX_AUDIO:
        raise HTTPException(413, f"At most {MAX_AUDIO} voice notes per check.")
    if not text.strip() and not images and not audios:
        raise HTTPException(400, "Paste a message, add a screenshot or a voice note.")

    uploaded: list[UploadedImage] = []
    for upload in images:
        if upload.content_type not in ALLOWED_IMAGE_TYPES:
            raise HTTPException(415, f"{upload.filename}: only PNG, JPEG or WebP images are supported.")
        data = await upload.read(MAX_IMAGE_BYTES + 1)
        if len(data) > MAX_IMAGE_BYTES:
            raise HTTPException(413, f"{upload.filename}: image is larger than 8 MB.")
        uploaded.append(UploadedImage(filename=upload.filename or "image", data=data, mime=upload.content_type))

    voice: list[UploadedAudio] = []
    for upload in audios:
        ctype = upload.content_type or ""
        if not (ctype.startswith("audio/") or ctype in ("video/mp4", "video/webm", "application/ogg", "application/octet-stream")):
            raise HTTPException(415, f"{upload.filename}: not an audio file.")
        data = await upload.read(MAX_AUDIO_BYTES + 1)
        if len(data) > MAX_AUDIO_BYTES:
            raise HTTPException(413, f"{upload.filename}: voice note is larger than 15 MB.")
        voice.append(UploadedAudio(filename=upload.filename or "voice-note", data=data))
    return uploaded, voice


@app.post("/api/analyze", response_model=AnalysisResponse)
async def post_analyze(
    text: str = Form(""),
    stage: Stage = Form("before_payment"),
    images: list[UploadFile] = File(default=[]),
    audios: list[UploadFile] = File(default=[]),
) -> AnalysisResponse:
    uploaded, voice = await _read_uploads(text, images, audios)
    # Uploads are processed in memory and not stored or logged.
    # analyze() blocks on the Gemma call; run it in a worker thread so checks don't queue behind each other.
    return await run_in_threadpool(analyze, text, uploaded, stage, voice)


@app.post("/api/analyze/stream")
async def post_analyze_stream(
    text: str = Form(""),
    stage: Stage = Form("before_payment"),
    images: list[UploadFile] = File(default=[]),
    audios: list[UploadFile] = File(default=[]),
) -> StreamingResponse:
    """Same as /api/analyze, but as Server-Sent Events: `progress` events while it works, then `result`."""
    uploaded, voice = await _read_uploads(text, images, audios)
    loop = asyncio.get_running_loop()
    queue: asyncio.Queue = asyncio.Queue()

    def progress(step: str, data: dict) -> None:
        loop.call_soon_threadsafe(queue.put_nowait, ("progress", {"step": step, **data}))

    async def worker() -> None:
        try:
            result = await run_in_threadpool(analyze, text, uploaded, stage, voice, progress)
            await queue.put(("result", result.model_dump(mode="json")))
        except Exception as exc:  # surface failures to the client instead of hanging the stream
            await queue.put(("error", {"detail": str(exc)[:300]}))
        await queue.put(None)

    async def events():
        task = asyncio.create_task(worker())
        try:
            while (item := await queue.get()) is not None:
                event, data = item
                yield f"event: {event}\ndata: {json.dumps(data, ensure_ascii=False)}\n\n"
        finally:
            task.cancel()

    return StreamingResponse(events(), media_type="text/event-stream", headers={"Cache-Control": "no-cache"})


@app.post("/api/agent", response_model=AgentResponse)
async def post_agent(req: AgentRequest) -> AgentResponse:
    if MOCK_MODE:
        raise HTTPException(503, "The agent needs online mode (Gemma).")
    try:
        return await run_in_threadpool(run_agent, req.analysis)
    except gemma.ModelError as exc:
        raise HTTPException(502, str(exc)) from exc


@app.post("/api/petition/draft", response_model=PetitionFields)
async def post_petition_draft(req: DraftRequest) -> PetitionFields:
    """The agent fills the Cyber Bureau application from the case; the user reviews every field."""
    if MOCK_MODE:
        raise HTTPException(503, "Drafting needs online mode (Gemma).")
    try:
        return await run_in_threadpool(draft_fields, req)
    except gemma.ModelError as exc:
        raise HTTPException(502, str(exc)) from exc


@app.post("/api/petition/pdf")
async def post_petition_pdf(
    payload: str = Form(...),
    exhibits: list[UploadFile] = File(default=[]),
) -> Response:
    """Render the reviewed application plus numbered annexes as a PDF. payload = {"fields": ..., "complainant": ...}."""
    try:
        body = json.loads(payload)
        fields = PetitionFields.model_validate(body.get("fields", {}))
        who = PetitionComplainant.model_validate(body.get("complainant", {}))
    except (ValueError, ValidationError) as exc:
        raise HTTPException(422, f"Invalid payload: {exc}") from exc
    files = []
    for upload in exhibits[:MAX_IMAGES]:
        data = await upload.read(MAX_IMAGE_BYTES + 1)
        if len(data) > MAX_IMAGE_BYTES or upload.content_type not in ALLOWED_IMAGE_TYPES:
            raise HTTPException(415, f"{upload.filename}: annexes must be PNG/JPEG/WebP images under 8 MB.")
        files.append((upload.filename or "screenshot", data, upload.content_type))
    pdf = await run_in_threadpool(render_pdf, fields, who, files)
    return Response(pdf, media_type="application/pdf",
                    headers={"Content-Disposition": 'attachment; filename="sajag-cyber-bureau-application.pdf"'})


@app.post("/api/complaint", response_model=ComplaintResponse)
def post_complaint(req: ComplaintRequest) -> ComplaintResponse:
    return ComplaintResponse(text_ne=build_complaint(req), resources=complaint_resources(req.recipient))


@app.post("/share-target")
def share_target_fallback() -> RedirectResponse:
    # Normally the service worker intercepts this; if it isn't active yet, just open the app.
    return RedirectResponse("/?share=failed", status_code=303)


# The Flutter app's web build (mobile/ -> flutter build web --base-href /app/), handy for demos on a laptop.
MOBILE_WEB = FRONTEND_DIST.parents[1] / "mobile" / "build" / "web"
if MOBILE_WEB.exists():
    app.mount("/app", StaticFiles(directory=MOBILE_WEB, html=True), name="mobile")

if FRONTEND_DIST.exists():
    app.mount("/", StaticFiles(directory=FRONTEND_DIST, html=True), name="frontend")
