
import os
import httpx

GLM_BASE_URL = os.getenv("GLM_BASE_URL", "https://api.z.ai/api/paas/v4")
GLM_MODEL = os.getenv("GLM_MODEL", "glm-4.5")


async def glm_chat(messages, max_tokens=700, temperature=0.3):
    api_key = os.getenv("GLM_API_KEY", "").strip()
    if not api_key:
        raise RuntimeError("GLM_API_KEY is not configured")

    async with httpx.AsyncClient(timeout=60) as client:
        resp = await client.post(
            f"{GLM_BASE_URL.rstrip('/')}/chat/completions",
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": GLM_MODEL,
                "messages": messages,
                "max_tokens": max_tokens,
                "temperature": temperature,
            },
        )
        resp.raise_for_status()
        data = resp.json()
        return data["choices"][0]["message"].get("content", "").strip(), data.get("usage", {})
