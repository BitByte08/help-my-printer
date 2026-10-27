"""PJL/PCL 스트림을 사람이 읽을 수 있는 명령 목록으로 요약한다.

같은 명령이 연속되면 한 줄로 묶고, 래스터 데이터 블록은 크기만 합산한다.
사용법: python pcl_dump.py FILE.prn [--payload-max N]
"""
import sys

ESC = 0x1B
UEL = b"\x1b%-12345X"
# 이 블록들은 페이로드를 그대로 보여준다. 나머지 데이터 블록은 크기만 센다.
SHOW_PAYLOAD = {"*g", "&b", "*o", "*v"}
RASTER = {"ESC *bW", "ESC *bV", "ESC *bY"}


def parse(data):
    """(kind, name, value, payload) 튜플을 차례로 내놓는다."""
    i, n = 0, len(data)
    while i < n:
        if data.startswith(UEL, i):
            i += len(UEL)
            yield ("uel", "UEL", "", b"")
            continue
        if data[i] == ESC:
            if i + 1 >= n:
                break
            c = data[i + 1]
            if not 0x21 <= c <= 0x2F:
                yield ("pcl", "ESC " + chr(c), "", b"")
                i += 2
                continue
            group, i = chr(c), i + 2
            param = ""
            if i < n and 0x60 <= data[i] <= 0x7E:
                param, i = chr(data[i]), i + 1
            # 그룹 하나에 값+파라미터가 여러 개 이어질 수 있다(소문자 종결 = 계속).
            while i < n:
                j = i
                while j < n and chr(data[j]) in "+-.0123456789":
                    j += 1
                value = data[i:j].decode("ascii") or "0"
                if j >= n:
                    i = j
                    break
                term = chr(data[j])
                i = j + 1
                cont = term.islower()
                name = group + param + term.upper()
                payload = b""
                if term.upper() in "WV":
                    length = int(float(value))
                    payload, i = data[i:i + length], i + length
                yield ("pcl", "ESC " + name, value, payload)
                if not cont:
                    break
            continue
        if data.startswith(b"@PJL", i):
            j = data.find(b"\n", i)
            j = n if j < 0 else j + 1
            yield ("pjl", data[i:j].decode("latin-1").rstrip(), "", b"")
            i = j
            continue
        j = i
        while j < n and data[j] != ESC:
            j += 1
        yield ("raw", "RAW", str(j - i), data[i:j])
        i = j


def main():
    path = sys.argv[1]
    payload_max = 64
    if "--payload-max" in sys.argv:
        payload_max = int(sys.argv[sys.argv.index("--payload-max") + 1])
    data = open(path, "rb").read()
    print(f"# {path} ({len(data)} bytes)")

    prev, count, total = None, 0, 0

    def flush():
        if prev is not None:
            print(f"RASTER {count} cmds, {total} bytes")

    for kind, name, value, payload in parse(data):
        # 래스터 행(*b V/W/Y)은 섞여서 반복되므로 하나의 묶음으로 센다.
        key = "RASTER" if kind == "pcl" and name in RASTER else None
        if key is not None and key == prev:
            count += 1
            total += len(payload)
            continue
        flush()
        prev, count, total = key, 1, len(payload)
        if key is not None:
            continue
        if kind == "pjl":
            print(name)
        elif kind == "raw":
            print(f"RAW {value} bytes: {payload[:payload_max].hex(' ')}")
        else:
            line = f"{name} {value}"
            if payload and (name[4:6] in SHOW_PAYLOAD):
                line += " : " + payload[:payload_max].hex(" ")
            elif payload:
                line += f" [{len(payload)} bytes]"
            print(line)
    flush()


if __name__ == "__main__":
    main()
