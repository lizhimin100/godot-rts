#!/usr/bin/env python3
"""Claude Code Vision Skill - 多模态视觉分析"""
import argparse, base64, json, os, sys, urllib.request

def encode_image(path):
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")

def get_mime(path):
    m = {".png":"image/png",".jpg":"image/jpeg",".jpeg":"image/jpeg",".gif":"image/gif",".webp":"image/webp"}
    return m.get(os.path.splitext(path)[1].lower(), "image/png")

def call_api(img, prompt, api_key, model, base_url):
    b64 = encode_image(img)
    payload = {"model":model,"messages":[{"role":"user","content":[{"type":"image_url","image_url":{"url":"data:" + get_mime(img) + ";base64," + b64}},{"type":"text","text":prompt}]}],"max_tokens":4096}
    req = urllib.request.Request(base_url + "/chat/completions",data=json.dumps(payload).encode("utf-8"),headers={"Content-Type":"application/json","Authorization":"Bearer " + api_key})
    try:
        return json.loads(urllib.request.urlopen(req,timeout=120).read().decode("utf-8"))["choices"][0]["message"]["content"]
    except Exception as e:
        return "[ERROR] " + str(e)

def main():
    p = argparse.ArgumentParser(description="Claude Code Vision Skill")
    p.add_argument("image",help="图片路径")
    p.add_argument("prompt",nargs="?",default="请详细描述这张图片")
    p.add_argument("--provider","-p",choices=["doubao","qwen","openai"],default=os.environ.get("VISION_PROVIDER","doubao"))
    p.add_argument("--model","-m")
    a = p.parse_args()
    if not os.path.exists(a.image):
        print("[ERROR] 文件不存在: " + a.image,file=sys.stderr)
        sys.exit(1)
    env_map={"doubao":"DOUBAO_API_KEY","qwen":"DASHSCOPE_API_KEY","openai":"OPENAI_API_KEY"}
    url_map={"doubao":"https://ark.cn-beijing.volces.com/api/v3","qwen":"https://dashscope.aliyuncs.com/compatible-mode/v1","openai":"https://api.openai.com/v1"}
    model_map={"doubao":"ep-m-20260425110124-hxkwj","qwen":"qwen-vl-max","openai":"gpt-4o"}
    ak = os.environ.get(env_map[a.provider],"")
    if not ak:
        print("[ERROR] 未设置 " + env_map[a.provider],file=sys.stderr)
        sys.exit(1)
    model = a.model or os.environ.get("VISION_MODEL", model_map[a.provider])
    base_url = os.environ.get(a.provider.upper() + "_BASE_URL", url_map[a.provider])
    print("[vision] 调用 " + a.provider + " 视觉模型 (" + model + ")...",file=sys.stderr)
    print(call_api(a.image,a.prompt,ak,model,base_url))

if __name__=="__main__":
    main()
