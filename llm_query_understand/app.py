from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from llm_query_understand.llm import LargeLanguageModel
from time import perf_counter

app = FastAPI()
llm = LargeLanguageModel()


@app.post("/chat")
async def chat(request: Request):
    body = await request.json()
    prompt = body.get("msg")
    start = perf_counter()
    response = llm.generate(prompt, max_length=100)
    generation_time = perf_counter() - start
    resp = {
        "generation_time": generation_time,
        "response": response,
        "prompt": prompt
    }
    return JSONResponse(content=resp)


print("App started")
