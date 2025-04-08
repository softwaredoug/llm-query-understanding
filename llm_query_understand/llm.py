from transformers import AutoTokenizer, AutoModelForCausalLM
import torch
import os


DEVICE = torch.device("cuda" if torch.cuda.is_available() else "mps" if torch.backends.mps.is_available() else "cpu")


def space_on_devices():
    print("Disk space:")
    os.system("df -h")
    # os.system("rm -rf /root/.cache/huggingface/")
    os.system("du -h /root/.cache/huggingface")


class LargeLanguageModel:

    def __init__(self, device=DEVICE, model="Qwen/Qwen2-7B"):
        self.device = device
        print(f"Using device: {self.device}")
        space_on_devices()
        self.tokenizer = AutoTokenizer.from_pretrained(model)
        print("Loading model...")
        self.model = AutoModelForCausalLM.from_pretrained(
            model,
            torch_dtype=torch.float16,
            device_map="auto"  # good for large models if using accelerate or bitsandbytes isn't needed
        ).to(self.device)
        print("Model loaded.")
        hello_world = self.generate("Hello, world!")
        print(f"Model output: {hello_world}")

    def generate(self, prompt: str, max_length: int = 100):
        print("Tokenizing...")
        inputs = self.tokenizer(prompt, return_tensors="pt")

        inputs = {k: v.to(self.device) for k, v in inputs.items()}
        # Just for logging/debugging
        print(f"Using device: {self.device}")
        for k, v in inputs.items():
            print(f"{k}: {v.device}")

        print("Generating...")
        outputs = self.model.generate(inputs["input_ids"], max_length=max_length)
        return self.tokenizer.decode(outputs[0], skip_special_tokens=True)
