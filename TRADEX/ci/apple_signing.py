#!/usr/bin/env python3
"""TRADEX용 임시 서명 자산 생성/삭제 — 앱 + 위젯 확장처럼 번들 ID가 여러 개일 때.
(FLYON·구독온은 ci/apple_signing.py를 그대로 쓴다)

CI용 임시 서명 자산 생성/삭제 (App Store Connect API 사용).

기기(UDID) 등록 없이 TestFlight용 빌드를 서명하기 위해, 실행할 때마다
  1) 배포 인증서(Apple Distribution)와 개인키를 새로 만들고
  2) App Store 배포용 프로비저닝 프로파일을 만든 뒤
  3) 빌드가 끝나면 둘 다 삭제한다.
App Store 배포용 프로파일에는 기기 등록이 필요 없다.

사용: apple_signing.py setup <출력폴더> | cleanup <출력폴더>
환경변수: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH, BUNDLE_IDS(쉼표 구분, 첫 번째가 앱), CAPABILITIES(앱에만), GITHUB_RUN_ID(선택)
"""
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, rsa
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature
from cryptography.x509.oid import NameOID

API = "https://api.appstoreconnect.apple.com/v1"


def b64u(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def make_token() -> str:
    with open(os.environ["ASC_KEY_PATH"], "rb") as f:
        key = serialization.load_pem_private_key(f.read(), password=None)
    now = int(time.time())
    header = {"alg": "ES256", "kid": os.environ["ASC_KEY_ID"], "typ": "JWT"}
    payload = {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"}
    signing_input = (
        b64u(json.dumps(header, separators=(",", ":")).encode())
        + "."
        + b64u(json.dumps(payload, separators=(",", ":")).encode())
    )
    r, s = decode_dss_signature(key.sign(signing_input.encode(), ec.ECDSA(hashes.SHA256())))
    return signing_input + "." + b64u(r.to_bytes(32, "big") + s.to_bytes(32, "big"))


def call(method: str, path: str, body=None, allow_404=False, soft=False):
    url = API + urllib.parse.quote(path, safe="/?=&[]")
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        url, method=method, data=data,
        headers={"Authorization": "Bearer " + make_token(), "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        if allow_404 and e.code == 404:
            return {}
        if soft:
            print(f"warning: API {e.code} on {method} {path}: {e.read().decode()[:300]}", file=sys.stderr)
            return None
        print(f"API error {e.code} on {method} {path}: {e.read().decode()[:1000]}", file=sys.stderr)
        raise SystemExit(1)


def find_or_create_bundle(identifier: str) -> str:
    found = call("GET", f"/bundleIds?filter[identifier]={identifier}&filter[platform]=IOS&limit=50")["data"]
    exact = [b for b in found if b["attributes"]["identifier"] == identifier]
    if exact:
        return exact[0]["id"]
    created = call("POST", "/bundleIds", {"data": {"type": "bundleIds", "attributes": {
        "identifier": identifier, "name": "TRADEX " + identifier.split(".")[-1], "platform": "IOS"}}})["data"]
    print(f"Registered bundle ID {identifier}")
    return created["id"]


def setup(outdir: str) -> None:
    os.makedirs(outdir, exist_ok=True)
    run = os.environ.get("GITHUB_RUN_ID", str(int(time.time())))
    bundles = [b.strip() for b in os.environ["BUNDLE_IDS"].split(",") if b.strip()]

    # 1) 개인키 + CSR -> 배포 인증서
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    csr = (
        x509.CertificateSigningRequestBuilder()
        .subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, f"TRADEX CI {run}")]))
        .sign(key, hashes.SHA256())
    )
    cert = call("POST", "/certificates", {"data": {
        "type": "certificates",
        "attributes": {
            "certificateType": "DISTRIBUTION",
            "csrContent": csr.public_bytes(serialization.Encoding.PEM).decode(),
        },
    }})["data"]
    state = {"certificate_id": cert["id"], "profiles": []}
    with open(os.path.join(outdir, "signing.json"), "w") as f:
        json.dump(state, f)
    with open(os.path.join(outdir, "key.pem"), "wb") as f:
        f.write(key.private_bytes(
            serialization.Encoding.PEM,
            serialization.PrivateFormat.TraditionalOpenSSL,
            serialization.NoEncryption(),
        ))
    os.chmod(os.path.join(outdir, "key.pem"), 0o600)
    with open(os.path.join(outdir, "distribution.cer"), "wb") as f:
        f.write(base64.b64decode(cert["attributes"]["certificateContent"]))

    for index, identifier in enumerate(bundles):
        bundle_resource_id = find_or_create_bundle(identifier)

        # 앱(첫 번째)에만 필요한 기능을 켠다
        if index == 0:
            caps = call("GET", f"/bundleIds/{bundle_resource_id}/bundleIdCapabilities", soft=True) or {"data": []}
            enabled = {c["attributes"].get("capabilityType") for c in caps.get("data", [])}
            for cap in [c for c in os.environ.get("CAPABILITIES", "").split(",") if c]:
                if cap not in enabled:
                    body = {"data": {"type": "bundleIdCapabilities",
                                     "attributes": {"capabilityType": cap},
                                     "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bundle_resource_id}}}}}
                    if cap == "APPLE_ID_AUTH":
                        body["data"]["attributes"]["settings"] = [{"key": "APPLE_ID_AUTH_APP_CONSENT",
                                                                   "options": [{"key": "PRIMARY_APP_CONSENT"}]}]
                    if call("POST", "/bundleIdCapabilities", body, soft=True) is not None:
                        print(f"Enabled capability {cap}")

        profile_name = f"TRADEX CI {run} {index}"
        prof = call("POST", "/profiles", {"data": {
            "type": "profiles",
            "attributes": {"name": profile_name, "profileType": "IOS_APP_STORE"},
            "relationships": {
                "bundleId": {"data": {"type": "bundleIds", "id": bundle_resource_id}},
                "certificates": {"data": [{"type": "certificates", "id": cert["id"]}]},
            },
        }})["data"]
        file_name = f"profile-{index}.mobileprovision"
        with open(os.path.join(outdir, file_name), "wb") as f:
            f.write(base64.b64decode(prof["attributes"]["profileContent"]))
        state["profiles"].append({"bundle": identifier, "id": prof["id"], "name": profile_name,
                                  "uuid": prof["attributes"]["uuid"], "file": file_name})
        with open(os.path.join(outdir, "signing.json"), "w") as f:
            json.dump(state, f)

    print(f"Created temporary certificate and {len(bundles)} profile(s)")


def cleanup(outdir: str) -> None:
    path = os.path.join(outdir, "signing.json")
    if not os.path.exists(path):
        print("Nothing to clean up")
        return
    with open(path) as f:
        state = json.load(f)
    for p in state.get("profiles", []):
        call("DELETE", f"/profiles/{p['id']}", allow_404=True)
    if state.get("certificate_id"):
        call("DELETE", f"/certificates/{state['certificate_id']}", allow_404=True)
    print("Deleted temporary certificate and profile")


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in ("setup", "cleanup"):
        print(__doc__)
        raise SystemExit(2)
    (setup if sys.argv[1] == "setup" else cleanup)(sys.argv[2])
