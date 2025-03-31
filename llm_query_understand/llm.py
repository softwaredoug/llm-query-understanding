from pydantic import BaseModel
from transformers import AutoTokenizer, AutoModelForCausalLM
import torch


DEVICE = torch.device("cuda" if torch.cuda.is_available() else "mps" if torch.backends.mps.is_available() else "cpu")


class LargeLanguageModel:

    def __init__(self, device=DEVICE, model="Qwen/Qwen2.5-7B"):
        self.device = device
        print(f"Using device: {self.device}")
        self.tokenizer = AutoTokenizer.from_pretrained(model)
        print("Loading model...")
        self.model = AutoModelForCausalLM.from_pretrained(model).to(self.device)

    def generate(self, prompt: str, max_length: int = 100):
        print("Tokenizing...")
        inputs = self.tokenizer(prompt, return_tensors="pt").to(self.device)
        print("Generating...")
        outputs = self.model.generate(inputs["input_ids"], max_length=max_length)
        print("Decoding...")
        return self.tokenizer.decode(outputs[0], skip_special_tokens=True)
