#!/usr/bin/env python3
"""Synthetic log writer for testing SwiftEdit's Log function (live tail direct/inverse).

Generates large log files in common .NET / logging-framework layouts and can keep appending
lines in real time, rotate or truncate the file, so the tail can be exercised exactly as with a
real service writing its log. Standard library only.

Formats (NLog is the primary target):
  nlog        NLog default layout  ${longdate}|${level:uppercase=true}|${logger}|${message}
  nlog-json   NLog JsonLayout      {"time":"...","level":"Info","logger":"...","message":"..."}
  nlog-csv    NLog CsvLayout       time;level;logger;message
  serilog     Serilog console      [HH:mm:ss INF] message
  log4net     log4net PatternLayout %date [%thread] %-5level %logger - %message
  syslog      RFC 3164             Nov 22 10:00:00 host app[pid]: info: message
  json        generic structured   {"timestamp":"...","severity":"ERROR","msg":"..."}
  mixed       random mix of all of the above

Examples:
  # 2 million NLog lines (~250 MB), then stop
  python3 Scripts/dev/log-writer.py --path /tmp/app.log --format nlog --lines 2000000
  # 10k mixed lines, then 20 lines/s for 60 s (watch it with Cmd+L / Shift+Cmd+L)
  python3 Scripts/dev/log-writer.py --path /tmp/app.log --format mixed --lines 10000 --rate 20 --duration 60
  # rotate every 5,000 live lines (app.log -> app.log.1, new app.log)
  python3 Scripts/dev/log-writer.py --path /tmp/app.log --rate 200 --duration 120 --rotate-every 5000

Exit codes: 0 success, 2 invalid arguments (argparse).
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import random
import sys
import time
import uuid

LEVELS = [("Trace", "TRC", 8), ("Debug", "DBG", 20), ("Info", "INF", 45), ("Warn", "WRN", 15), ("Error", "ERR", 9), ("Fatal", "FTL", 3)]
LOGGERS = ["Shop.Api.OrdersController", "Shop.Payments.Gateway", "Shop.Data.Repository", "Microsoft.Hosting.Lifetime", "Shop.Workers.Mailer"]
MESSAGES = [
    "Request {id} completed in {ms} ms",
    "Cache miss for key \"order:{n}\"",
    "Retrying payment {id} (attempt {n})",
    "User {n} signed in from 10.0.{n}.{ms}",
    "Low stock for SKU-{n}: {ms} left",
    "Unhandled System.InvalidOperationException: sequence contains no elements",
    "Database timeout after {ms} ms on query {id}",
]
STACK = ["   at Shop.Data.Repository.GetOrder(Guid id) in Repository.cs:line {n}",
         "   at Shop.Api.OrdersController.Get(Guid id) in OrdersController.cs:line {n}"]
FORMATS = ["nlog", "nlog-json", "nlog-csv", "serilog", "log4net", "syslog", "json"]


def pick_level(rng: random.Random) -> tuple[str, str]:
    weights = [w for _, _, w in LEVELS]
    name, short, _ = rng.choices(LEVELS, weights=weights, k=1)[0]
    return name, short


def render(fmt: str, rng: random.Random, now: dt.datetime) -> list[str]:
    """Returns one log record (one line, plus stack-frame lines for some errors)."""
    if fmt == "mixed":
        fmt = rng.choice(FORMATS)
    level, short = pick_level(rng)
    logger = rng.choice(LOGGERS)
    message = rng.choice(MESSAGES).format(id=uuid.UUID(int=rng.getrandbits(128)), ms=rng.randint(1, 900), n=rng.randint(1, 9999))
    stamp = now.strftime("%Y-%m-%d %H:%M:%S.") + f"{now.microsecond // 100:04d}"
    if fmt == "nlog":
        line = f"{stamp}|{level.upper()}|{logger}|{message}"
    elif fmt == "nlog-json":
        line = json.dumps({"time": now.isoformat(timespec="milliseconds"), "level": level, "logger": logger, "message": message})
    elif fmt == "nlog-csv":
        line = f"{stamp};{level.upper()};{logger};\"{message}\""
    elif fmt == "serilog":
        line = f"[{now.strftime('%H:%M:%S')} {short}] {message}"
    elif fmt == "log4net":
        line = f"{now.strftime('%Y-%m-%d %H:%M:%S')},{now.microsecond // 1000:03d} [{rng.randint(1, 32)}] {level.upper():<5} {logger} - {message}"
    elif fmt == "syslog":
        line = f"{now.strftime('%b %d %H:%M:%S')} host shop[{os.getpid()}]: {level.lower()}: {message}"
    else:
        line = json.dumps({"timestamp": now.isoformat(timespec="seconds"), "severity": level.upper(), "msg": message})
    lines = [line]
    if level in ("Error", "Fatal") and rng.random() < 0.5 and not fmt.endswith("json"):
        lines += [frame.format(n=rng.randint(10, 400)) for frame in STACK]
    return lines


def rotate(path: str) -> None:
    if os.path.exists(path):
        os.replace(path, path + ".1")


def write_bulk(path: str, fmt: str, count: int, rng: random.Random) -> None:
    start = dt.datetime.now() - dt.timedelta(seconds=count / 1000)
    with open(path, "a", encoding="utf-8", newline="\n") as handle:
        buffer: list[str] = []
        for i in range(count):
            buffer += render(fmt, rng, start + dt.timedelta(milliseconds=i))
            if len(buffer) >= 5000:
                handle.write("\n".join(buffer) + "\n")
                buffer.clear()
        if buffer:
            handle.write("\n".join(buffer) + "\n")


def write_live(args: argparse.Namespace, rng: random.Random) -> None:
    interval = 1.0 / args.rate
    deadline = time.monotonic() + args.duration
    written = 0
    while time.monotonic() < deadline:
        if args.rotate_every and written and written % args.rotate_every == 0:
            rotate(args.path)
        if args.truncate_every and written and written % args.truncate_every == 0:
            open(args.path, "w").close()
        with open(args.path, "a", encoding="utf-8", newline="\n") as handle:
            handle.write("\n".join(render(args.format, rng, dt.datetime.now())) + "\n")
        written += 1
        time.sleep(interval)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Synthetic log writer for SwiftEdit log-tail testing.")
    parser.add_argument("--path", required=True, help="log file to append to (created if missing)")
    parser.add_argument("--format", default="nlog", choices=FORMATS + ["mixed"])
    parser.add_argument("--lines", type=int, default=0, help="records written immediately (bulk)")
    parser.add_argument("--rate", type=float, default=0.0, help="live records per second after the bulk (0 = no live phase)")
    parser.add_argument("--duration", type=float, default=30.0, help="seconds of live writing")
    parser.add_argument("--rotate-every", type=int, default=0, help="rotate after N live records (path -> path.1)")
    parser.add_argument("--truncate-every", type=int, default=0, help="truncate after N live records")
    parser.add_argument("--seed", type=int, default=None, help="random seed for reproducible output")
    args = parser.parse_args(argv)
    if args.lines < 0 or args.rate < 0 or args.duration < 0:
        parser.error("--lines, --rate and --duration must be >= 0")
    return args


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    rng = random.Random(args.seed)
    if args.lines:
        write_bulk(args.path, args.format, args.lines, rng)
    if args.rate > 0:
        write_live(args, rng)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
