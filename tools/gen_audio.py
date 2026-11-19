"""HANDLER 程序化音效生成器 —— 纯 numpy，无外部素材。
运行：python tools/gen_audio.py
"""
import os
import wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio")


def env(n, attack=0.005, decay=1.0, curve=3.0):
    t = np.linspace(0, 1, n)
    a = np.clip(t / max(attack, 1e-5), 0, 1)
    d = np.exp(-t * curve / max(decay, 1e-5))
    return a * d


def noise(n):
    return np.random.uniform(-1, 1, n)


def lowpass(x, cutoff):
    """一阶低通"""
    if cutoff >= SR / 2:
        return x
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def bandpass(x, lo, hi):
    return highpass(lowpass(x, hi), lo)


def sweep(f0, f1, dur, kind="sine"):
    n = int(SR * dur)
    t = np.arange(n) / SR
    f = np.linspace(f0, f1, n)
    ph = 2 * np.pi * np.cumsum(f) / SR
    if kind == "sine":
        return np.sin(ph)
    if kind == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1.0) - 1
    return np.sign(np.sin(ph))


def reverb(x, amount=0.25, decay=0.35):
    n = int(SR * decay)
    ir = np.random.uniform(-1, 1, n) * np.exp(-np.arange(n) / (n * 0.35))
    ir = lowpass(ir, 5000)
    ir /= np.max(np.abs(ir)) + 1e-9
    wet = np.convolve(x, ir, mode="full")[: len(x)]
    return x * (1 - amount) + wet * amount * 2.0


def norm(x, peak=0.85):
    m = np.max(np.abs(x))
    if m < 1e-9:
        return x
    return x / m * peak


def save(name, x):
    x = norm(np.tanh(x * 1.1), 0.86)
    data = (x * 32767).astype(np.int16)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("  ", name, f"{len(x)/SR:.2f}s")


def fade(x, ms=8):
    n = int(SR * ms / 1000)
    if n * 2 >= len(x):
        return x
    e = np.ones(len(x))
    e[:n] = np.linspace(0, 1, n)
    e[-n:] = np.linspace(1, 0, n)
    return x * e


def main():
    os.makedirs(OUT, exist_ok=True)
    np.random.seed(86)
    print("生成音效 ->", OUT)

    # 1. 下令：短促的双音确认
    n = int(SR * 0.16)
    x = sweep(880, 1320, 0.07) * env(int(SR * 0.07), 0.002, 0.12, 5)
    y = sweep(1320, 1760, 0.09) * env(int(SR * 0.09), 0.002, 0.14, 5)
    sig = np.zeros(n)
    sig[: len(x)] += x
    sig[int(SR * 0.06): int(SR * 0.06) + len(y)] += y * 0.8
    save("sfx_command", reverb(sig, 0.12, 0.2))

    # 2. 确认
    sig = sweep(1200, 900, 0.12) * env(int(SR * 0.12), 0.002, 0.16, 4)
    save("sfx_confirm", reverb(sig, 0.1, 0.15))

    # 3. 拒绝
    sig = sweep(300, 180, 0.18, "saw") * env(int(SR * 0.18), 0.003, 0.2, 4)
    save("sfx_deny", reverb(sig, 0.1, 0.12))

    # 4. 扫描 / 点亮
    n = int(SR * 0.9)
    t = np.arange(n) / SR
    sw = sweep(200, 2400, 0.9) * env(n, 0.01, 0.9, 2.0)
    hiss = bandpass(noise(n), 1500, 9000) * env(n, 0.01, 0.5, 3.0) * 0.35
    save("sfx_scan", reverb(sw * 0.7 + hiss, 0.3, 0.4))

    # 5. 命中
    n = int(SR * 0.12)
    sig = bandpass(noise(n), 800, 6000) * env(n, 0.001, 0.1, 8)
    save("sfx_hit", sig)

    # 6. 步枪
    n = int(SR * 0.1)
    sig = bandpass(noise(n), 600, 5000) * env(n, 0.0005, 0.06, 12)
    sig += np.sin(2 * np.pi * 90 * np.arange(n) / SR) * env(n, 0.001, 0.05, 10) * 0.5
    save("sfx_rifle", sig)

    # 7. 炮击
    n = int(SR * 0.5)
    sig = bandpass(noise(n), 120, 2500) * env(n, 0.002, 0.28, 5)
    sig += np.sin(2 * np.pi * 55 * np.arange(n) / SR) * env(n, 0.002, 0.3, 4) * 0.8
    save("sfx_cannon", reverb(sig, 0.2, 0.3))

    # 8. 爆炸
    n = int(SR * 0.9)
    t = np.arange(n) / SR
    boom = np.sin(2 * np.pi * (70 - 40 * t / 0.9) * t) * env(n, 0.002, 0.5, 4)
    crack = bandpass(noise(n), 200, 7000) * env(n, 0.001, 0.35, 6) * 0.8
    save("sfx_explosion", reverb(boom * 0.8 + crack, 0.32, 0.5))

    # 9. 大爆炸
    n = int(SR * 1.6)
    t = np.arange(n) / SR
    boom = np.sin(2 * np.pi * (55 - 35 * t / 1.6) * t) * env(n, 0.003, 0.9, 3)
    crack = bandpass(noise(n), 80, 8000) * env(n, 0.001, 0.7, 4) * 0.9
    save("sfx_explosion_big", reverb(boom * 0.9 + crack, 0.4, 0.9))

    # 10. 电极 / 干扰
    n = int(SR * 0.7)
    t = np.arange(n) / SR
    sig = np.sin(2 * np.pi * (400 + 300 * np.sin(2 * np.pi * 13 * t)) * t)
    sig *= (np.random.rand(n) > 0.35).astype(float)
    sig *= env(n, 0.01, 0.6, 3)
    sig += bandpass(noise(n), 2000, 12000) * 0.25
    save("sfx_jam", reverb(sig, 0.2, 0.3))

    # 11. 阵亡通讯中断
    n = int(SR * 1.1)
    t = np.arange(n) / SR
    sig = bandpass(noise(n), 300, 4000) * (0.5 + 0.5 * np.sin(2 * np.pi * 9 * t))
    sig *= np.exp(-t * 2.2)
    sig += np.sin(2 * np.pi * 220 * t) * np.exp(-t * 6) * 0.4
    save("sfx_death_signal", reverb(sig, 0.3, 0.4))

    # 12. 警报
    n = int(SR * 0.8)
    t = np.arange(n) / SR
    sig = np.sin(2 * np.pi * 620 * t) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 4 * t)))
    sig *= env(n, 0.01, 0.7, 2)
    save("sfx_alarm", reverb(sig, 0.2, 0.3))

    # 13. 波次开始
    n = int(SR * 1.0)
    t = np.arange(n) / SR
    sig = np.sin(2 * np.pi * (110 + 20 * np.sin(2 * np.pi * 2 * t)) * t)
    sig += np.sin(2 * np.pi * 165 * t) * 0.5
    sig *= env(n, 0.02, 0.8, 2)
    save("sfx_wave", reverb(sig, 0.25, 0.4))

    # 14. UI 点击
    n = int(SR * 0.06)
    sig = sweep(1600, 1200, 0.06) * env(n, 0.001, 0.05, 9)
    save("sfx_ui", sig)

    # 15. 无线电开/关
    for nm, up in (("sfx_radio_open", True), ("sfx_radio_close", False)):
        n = int(SR * 0.22)
        t = np.arange(n) / SR
        f = np.linspace(700, 1400, n) if up else np.linspace(1400, 700, n)
        sig = bandpass(noise(n), 400, 5000) * 0.6
        sig += np.sin(2 * np.pi * f * t) * 0.4
        sig *= env(n, 0.004, 0.2, 3)
        save(nm, sig)

    # 16. 环境底噪（循环 8s）
    n = int(SR * 8)
    t = np.arange(n) / SR
    base = lowpass(noise(n), 320) * 0.5
    hum = np.sin(2 * np.pi * 48 * t) * 0.12 + np.sin(2 * np.pi * 96 * t) * 0.05
    pulse = (0.6 + 0.4 * np.sin(2 * np.pi * 0.13 * t))
    amb = (base + hum) * pulse
    save("amb_drone", amb)

    # 17. 紧张音乐床（循环 12s）
    n = int(SR * 12)
    t = np.arange(n) / SR
    layers = np.zeros(n)
    for f, a in ((55, 0.5), (82.5, 0.3), (110, 0.18), (164.8, 0.1)):
        layers += np.sin(2 * np.pi * f * t + np.sin(2 * np.pi * 0.07 * t)) * a
    layers *= 0.55 + 0.45 * np.sin(2 * np.pi * 0.055 * t)
    perc = np.zeros(n)
    for i in range(16):
        st = int(SR * (i * 0.75 + 0.1))
        m = int(SR * 0.25)
        if st + m < n:
            perc[st: st + m] += bandpass(noise(m), 900, 4000) * env(m, 0.002, 0.2, 5) * 0.16
    save("mus_dread", layers * 0.7 + perc)

    # 18. 脉冲点亮
    n = int(SR * 0.5)
    t = np.arange(n) / SR
    sig = np.sin(2 * np.pi * (300 + 900 * t / 0.5) * t) * env(n, 0.005, 0.35, 3)
    save("sfx_pulse", reverb(sig, 0.2, 0.3))

    print("完成。")


if __name__ == "__main__":
    main()
