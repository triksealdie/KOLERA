import json
import os
import sys
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlparse

def _resolve_base_dir():
    env_dir = os.environ.get("KOLERA_BASE_DIR")
    candidates = []
    if env_dir:
        candidates.append(Path(env_dir))
    if getattr(sys, "frozen", False):
        exe_dir = Path(sys.executable).resolve().parent
        parent = exe_dir.parent
        candidates.append(parent)
        candidates.append(exe_dir)
    else:
        here = Path(__file__).resolve().parent
        parent = here.parent
        candidates.append(parent)
        candidates.append(here)
    candidates.append(Path.cwd())

    for c in candidates:
        if (c / "config").is_dir():
            return c
    return candidates[0]

BASE_DIR = _resolve_base_dir()
EXE_DIR = Path(sys.executable).resolve().parent if getattr(sys, "frozen", False) else Path(__file__).resolve().parent
CONFIG_DIR = BASE_DIR / "config"
CONFIG_FILE = CONFIG_DIR / "local_config.json"
# Host que usará el exe para abrir el panel; dejamos kolera.rad por defecto
PANEL_HOST = "kolera.rad"
TARGET_PANEL_URL = f"http://{PANEL_HOST}/config"


def _force_panel_url(url: str):
    """
    Refuerza la URL del panel en todos los sitios posibles:
    - variable de entorno (para defaults)
    - atributos en kolera_skr si está cargado
    """
    os.environ["KOLERA_PANEL_URL"] = url
    try:
        import kolera_skr as ks

        ks._CONFIG_PANEL_URL = url
        ks._CONFIG_PANEL_URL_RUNTIME = url
    except Exception:
        pass

# Forzamos inmediatamente al cargar el módulo (por si el exe ya está importado)
_force_panel_url(TARGET_PANEL_URL)

if (BASE_DIR / "config_panel" / "index.html").exists():
    STATIC_DIR = BASE_DIR / "config_panel"
elif (EXE_DIR / "config_panel" / "index.html").exists():
    STATIC_DIR = EXE_DIR / "config_panel"
else:
    STATIC_DIR = BASE_DIR / "config_panel"

DEFAULT_PROFILE = {
    "name": "Local",
    "fovX": 80,
    "fovY": 30,
    "smoothX": 10,
    "smoothY": 10,
    "offset": 7,
    "color": "Purple",
    "bone": "Head",
    "mainKey": "LCLICK",
    "toggleKey": "F2",
    # nuevos campos para control fino
    "magnetKey": "XBUTTON1",  # Mouse4 (coincide con _K_MAGNET = 5)
    "triggerKey": "ALT",      # Alt (coincide con _K_TRIGGER = 18)
}

DEFAULT_CONFIG = {"activeProfile": 0, "profiles": [DEFAULT_PROFILE]}
BANNER_LINES = [
    "██╗  ██╗ ██████╗ ██╗     ███████╗██████╗  █████╗ ",
    "██║ ██╔╝██╔═══██╗██║     ██╔════╝██╔══██╗██╔══██╗",
    "█████╔╝ ██║   ██║██║     █████╗  ██████╔╝███████║",
    "██╔═██╗ ██║   ██║██║     ██╔══╝  ██╔══██╗██╔══██║",
    "██║  ██╗╚██████╔╝███████╗███████╗██║  ██║██║  ██║",
    "╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝",
]


def _render_banner():
    """Reimprime un banner simple sin depender del exe."""
    try:
        print()
        print("\n".join(BANNER_LINES))
    except Exception:
        pass


def _clamp_int(value, low, high, fallback):
    try:
        v = float(value)
    except Exception:
        return fallback
    try:
        v = int(round(v))
    except Exception:
        v = fallback
    return max(low, min(high, v))


def _clean_config(payload):
    if isinstance(payload, dict) and "config" in payload:
        payload = payload.get("config", {})

    if not isinstance(payload, dict):
        payload = {}

    profiles = payload.get("profiles", [])
    if not profiles or not isinstance(profiles, list):
        profiles = [payload]

    idx = payload.get("activeProfile", 0) or 0
    if idx < 0 or idx >= len(profiles):
        idx = 0
    raw = profiles[idx] or {}

    def pick(name, default):
        return raw.get(name, default)

    # smooth values in tenths: 65 -> 6.5 in the exe
    smx = _clamp_int(float(pick("smoothX", DEFAULT_PROFILE["smoothX"])) * 10, 1, 300, DEFAULT_PROFILE["smoothX"] * 10)
    smy = _clamp_int(float(pick("smoothY", DEFAULT_PROFILE["smoothY"])) * 10, 1, 300, DEFAULT_PROFILE["smoothY"] * 10)
    off = _clamp_int(pick("offset", DEFAULT_PROFILE["offset"]), 0, 50, DEFAULT_PROFILE["offset"])

    cfg_profile = {
        "name": str(pick("name", DEFAULT_PROFILE["name"])),
        "fovX": _clamp_int(pick("fovX", DEFAULT_PROFILE["fovX"]), 5, 500, DEFAULT_PROFILE["fovX"]),
        "fovY": _clamp_int(pick("fovY", DEFAULT_PROFILE["fovY"]), 5, 500, DEFAULT_PROFILE["fovY"]),
        "smoothX": smx,
        "smoothY": smy,
        "offset": off,
        "color": str(pick("color", DEFAULT_PROFILE["color"])).capitalize(),
        "bone": str(pick("bone", DEFAULT_PROFILE["bone"])).capitalize(),
        "mainKey": str(pick("mainKey", DEFAULT_PROFILE["mainKey"])).upper(),
        "toggleKey": str(pick("toggleKey", DEFAULT_PROFILE["toggleKey"])).upper(),
        # nuevos
        "magnetKey": str(pick("magnetKey", DEFAULT_PROFILE["magnetKey"])).upper(),
        "triggerKey": str(pick("triggerKey", DEFAULT_PROFILE["triggerKey"])).upper(),
    }

    return {"activeProfile": 0, "profiles": [cfg_profile]}


def _load_config():
    try:
        with open(CONFIG_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, dict) and "config" in data:
            data = data.get("config", {})
        if not data:
            return DEFAULT_CONFIG
        data.setdefault("activeProfile", 0)
        if not data.get("profiles"):
            data["profiles"] = DEFAULT_CONFIG["profiles"]
        return data
    except Exception:
        return DEFAULT_CONFIG


def _save_config(cfg):
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    wrapped = {"config": cfg}
    CONFIG_FILE.write_text(json.dumps(wrapped, indent=2), encoding="utf-8")
    print(f"[cfg] Guardado en {CONFIG_FILE}")

def _apply_live_config():
    """
    Recarga y aplica la config al exe inmediatamente, sin esperar a F9.
    """
    try:
        import kolera_skr as ks
        cfg, _ = ks.load_config_local(ks._LOCAL_CONFIG_PATH)
        ks.apply_config(cfg)
        _render_banner()
        print(f"[cfg] Aplicada en caliente: tint={cfg.get('tint')} fov_x={cfg.get('fov_x')} fov_y={cfg.get('fov_y')} spd_x={cfg.get('spd_x')} spd_y={cfg.get('spd_y')} trigger={cfg.get('trigger')} toggle={cfg.get('toggle')}")
    except Exception as e:
        print(f"[cfg] Error al aplicar en caliente: {e}")


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(STATIC_DIR), **kwargs)

    def end_headers(self):
        # fuerza no-cache para que el panel siempre se recargue como Ctrl+F5
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def _write_json(self, payload, status=200):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        # cleaner console output
        print(f"[{self.log_date_time_string()}] {self.client_address[0]} {self.command} {self.path} {' '.join(map(str, args))}")

    def do_GET(self):
        parsed = urlparse(self.path)
        # Permitir servir bajo / y bajo /config (cuando se abre http://kolera.rad/config)
        path = parsed.path or "/"
        if path.startswith("/config/"):
            path = path[len("/config") :]
            if not path.startswith("/"):
                path = "/" + path
        elif path == "/config":
            path = "/"

        if path in ("", "/"):
            self.path = "/index.html"
            return super().do_GET()
        if path == "/api/config":
            cfg = _load_config()
            self._write_json({"config": cfg, "path": str(CONFIG_FILE)})
            return
        if path == "/api/default":
            self._write_json({"config": DEFAULT_CONFIG, "path": str(CONFIG_FILE)})
            return
        # Servir estáticos también con el prefijo ya limpiado
        self.path = path
        return super().do_GET()

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path or "/"
        if path.startswith("/config/"):
            path = path[len("/config") :]
            if not path.startswith("/"):
                path = "/" + path
        elif path == "/config":
            path = "/"

        if path != "/api/config":
            self.send_error(404, "Not found")
            return

        length = int(self.headers.get("Content-Length", "0") or 0)
        raw_body = self.rfile.read(length) if length > 0 else b"{}"
        try:
            payload = json.loads(raw_body.decode("utf-8") or "{}")
        except Exception:
            self._write_json({"error": "Invalid JSON body"}, status=400)
            return

        cfg = _clean_config(payload)
        _save_config(cfg)
        _apply_runtime_keys(cfg.get("profiles", [{}])[0])
        _apply_live_config()
        self._write_json({"ok": True, "config": cfg, "path": str(CONFIG_FILE)})


def _apply_runtime_keys(profile):
    """
    Actualiza las teclas magnet y trigger en el exe en caliente.
    """
    try:
        import kolera_skr as ks
        keymap = getattr(ks, "_KEY_MAP", {})
        ks._K_MAGNET = keymap.get(profile.get("magnetKey", DEFAULT_PROFILE["magnetKey"]).upper(), ks._K_MAGNET)
        ks._K_TRIGGER = keymap.get(profile.get("triggerKey", DEFAULT_PROFILE["triggerKey"]).upper(), ks._K_TRIGGER)
    except Exception:
        # mantener silencio en caso de que no estÃ© cargado el exe
        pass


def _patch_kolera_loaders():
    """
    Envuelve load_config_local / load_config_from_api para aplicar teclas
    al refrescar config (F9 o arranque) sin tocar el binario.
    """
    try:
        import kolera_skr as ks
        import json
    except Exception:
        return

    if getattr(ks, "_PATCHED_EXTRA_KEYS", False):
        return

    def _profile_from_file(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                raw = json.load(f)
            if isinstance(raw, dict) and "config" in raw:
                raw = raw.get("config", {})
            profiles = raw.get("profiles", []) if isinstance(raw, dict) else []
            idx = raw.get("activeProfile", 0) if isinstance(raw, dict) else 0
            if idx < 0 or idx >= len(profiles):
                idx = 0
            return profiles[idx] if profiles else {}
        except Exception:
            return {}

    _orig_local = ks.load_config_local

    def _wrap_local(path=ks._LOCAL_CONFIG_PATH):
        profile = _profile_from_file(path)
        _apply_runtime_keys(profile)
        return _orig_local(path)

    ks.load_config_local = _wrap_local

    _orig_api = ks.load_config_from_api

    def _wrap_api(lic):
        cfg, slot = _orig_api(lic)
        try:
            profiles = cfg.get("profiles", []) if isinstance(cfg, dict) else []
            prof = profiles[slot - 1] if slot and slot - 1 < len(profiles) else (profiles[0] if profiles else {})
            _apply_runtime_keys(prof)
        except Exception:
            pass
        return cfg, slot

    ks.load_config_from_api = _wrap_api
    ks._PATCHED_EXTRA_KEYS = True


def _patch_brand():
    """
    Evita que el ASCII de Kolera desaparezca tras clear_screen/toggles.
    Sustituye clear_screen por una versiÃ³n que reimprime el banner.
    """
    try:
        import kolera_skr as ks
    except Exception:
        return
    if getattr(ks, "_PATCHED_BRAND", False):
        return
    if not hasattr(ks, "clear_screen") or not hasattr(ks, "print_banner"):
        return
    _orig_clear = ks.clear_screen

    def _clear_and_brand():
        _orig_clear()
        try:
            ks.print_banner()
        except Exception:
            pass

    ks.clear_screen = _clear_and_brand
    ks._PATCHED_BRAND = True


def _patch_apply_banner():
    """
    Asegura que apply_config vuelva a mostrar el banner aunque no se llame clear_screen.
    """
    try:
        import kolera_skr as ks
    except Exception:
        return
    if getattr(ks, "_PATCHED_APPLY_BANNER", False):
        return
    if not hasattr(ks, "apply_config"):
        return

    _orig_apply = ks.apply_config

    def _apply_and_brand(cfg):
        res = _orig_apply(cfg)
        _render_banner()
        return res

    ks.apply_config = _apply_and_brand
    ks._PATCHED_APPLY_BANNER = True


def _set_panel_url_runtime(port):
    """
    Ajusta la URL de panel que usa el exe (F10) para abrir kolera.rad.
    """
    try:
        import kolera_skr as ks
    except Exception:
        return
    # Construye la URL pública que queremos que abra F10
    base = f"http://{PANEL_HOST}"
    url = f"{base}/config" if str(port) == "80" else f"{base}:{port}/config"
    ks._CONFIG_PANEL_URL_RUNTIME = url
    # aseguramos también la URL base que usa F10
    ks._CONFIG_PANEL_URL = url
    os.environ["KOLERA_PANEL_URL"] = url
    print(f"[cfg] Panel URL set to {url}")


def main():
    # Forzar puerto 80 por defecto; si PORT está definido se respeta solo si es 80
    env_port = os.environ.get("PORT", "80")
    port = 80 if env_port.strip() != "80" else 80
    httpd = HTTPServer(("0.0.0.0", port), Handler)
_patch_kolera_loaders()
_patch_brand()
_patch_apply_banner()
_set_panel_url_runtime(port)
    print(f"Config server running on http://127.0.0.1:{port}")
    print("API: GET/POST /api/config, defaults at /api/default, UI served from config_panel/")
    print(f"Writing config to {CONFIG_FILE}")
    print(f"Serving static from {STATIC_DIR}")
    httpd.serve_forever()


if __name__ == "__main__":
    main()

