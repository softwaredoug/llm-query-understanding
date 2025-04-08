from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from llm_query_understand.llm import LargeLanguageModel
from time import perf_counter
import redis

app = FastAPI()
llm = LargeLanguageModel()
r = redis.Redis(host='val-key', port=6379, decode_responses=True)


@app.post("/chat")
async def chat(request: Request):
    print("Received request")
    body = await request.json()
    prompt = body.get("msg")
    start = perf_counter()
    print(f"Responding to prompt: {prompt}")
    response = llm.generate(prompt, max_length=100)
    generation_time = perf_counter() - start
    print(f"Generation time: {generation_time:.2f} seconds")
    resp = {
        "generation_time": generation_time,
        "response": response,
        "prompt": prompt
    }
    return JSONResponse(content=resp)


print("App started")

# Test redis
r.set("test", "test")
print("Redis test key set")
test_value = r.get("test")
print(f"Redis test key value: {test_value}")
