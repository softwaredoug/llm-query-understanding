from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from llm_query_understand.llm import LargeLanguageModel

app = FastAPI()
llm = LargeLanguageModel()


@app.post("/echo")
async def echo(request: Request):
    body = await request.json()
    prompt = body.get("msg")
    print("Test")
    # response = llm.generate(prompt, max_length)
    echo = f"Echo: {prompt}"
    resp = {"echo": echo}
    return JSONResponse(content=resp)


print("App started")
