"""HANDLER 程序化音效（v2）—— 柔和版。

原则：
  · 只用正弦 / 三角 / 极低通噪声，不用方波、锯齿、生噪。
  · 每个音都有柔和的起音与指数衰减，尾巴带一点混响。
  · 峰值压到 0.5 左右，长音更轻，避免疲劳。

运行：python tools/gen_audio.py
"""
import os
import wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio")


# ---------------- 基础工具 ----------------
def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def sine(freq, dur, phase=0.0):
    t = t_axis(dur)
    if np.isscalar(freq):
        ph = 2 * np.pi * freq * t
    else:
        ph = 2 * np.pi * np.cumsum(freq) / SR
    return np.sin(ph + phase)


def tri(freq, dur):
    t = t_axis(dur)
    ph = 2 * np.pi * freq * t
    return 2.0 / np.pi * np.arcsin(np.sin(ph))


def env_ad(n, attack=0.008, decay=0.25, curve=3.0):
    """平滑起音 + 指数衰减（无爆音）"""
    t = np.linspace(0, 1, n)
    a = np.clip(t / max(attack, 1e-6), 0, 1)
    a = a * a * (3 - 2 * a)          # smoothstep，起音更软
    d = np.exp(-t * curve / max(decay, 1e-6))
    return a * d


def one_pole_lp(x, cutoff):
    if cutoff >= SR / 2:
        return x
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def soft_noise(dur, cutoff=1800.0):
    """极低通噪声：像风，不像静电"""
    n = int(SR * dur)
    x = np.random.uniform(-1, 1, n)
    x = one_pole_lp(x, cutoff)
    x = one_pole_lp(x, cutoff)
    return x


def reverb_soft(x, wet=0.22, decay=0.28):
    n = int(SR * decay)
    ir = np.random.uniform(-1, 1, n) * np.exp(-np.arange(n) / (n * 0.4))
    ir = one_pole_lp(ir, 2600)
    ir = np.concatenate([np.zeros(6), ir])       # 一点点预延迟，更自然
    ir /= np.max(np.abs(ir)) + 1e-9
    wet_sig = np.convolve(x, ir, mode="full")[: len(x)]
    return x * (1 - wet) + wet_sig * wet * 1.6


def normalize(x, peak=0.5):
    m = np.max(np.abs(x))
    return x if m < 1e-9 else x / m * peak


def fade(x, ms=10):
    n = int(SR * ms / 1000)
    if n * 2 >= len(x):
        return x
    e = np.ones(len(x))
    e[:n] = np.linspace(0, 1, n)
    e[-n:] = np.linspace(1, 0, n)
    return x * e


def save(name, x, peak=0.5):
    # 统一柔化：低通 + 低峰值，去掉一切刺耳的高频和爆点
    x = one_pole_lp(x, 2600)
    x = one_pole_lp(x, 2600)
    x = normalize(np.tanh(x * 0.55), min(peak, 0.30))
    x = fade(x, 14)
    data = (x * 32767).astype(np.int16)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("  %-20s %.2fs" % (name, len(x) / SR))


# ---------------- 音效 ----------------
def main():
    os.makedirs(OUT, exist_ok=True)
    np.random.seed(86)
    print("生成音效 v2 ->", OUT)

    # 1 下令：两声柔和的上行钟
    a = sine(660, 0.10) * env_ad(int(SR * 0.10), 0.004, 0.16, 4)
    b = sine(880, 0.14) * env_ad(int(SR * 0.14), 0.004, 0.20, 4)
    sig = np.zeros(int(SR * 0.26))
    sig[: len(a)] += a * 0.55
    off = int(SR * 0.07)
    sig[off: off + len(b)] += b * 0.42
    save("sfx_command", reverb_soft(sig, 0.25, 0.25), 0.42)

    # 2 确认：单音短钟
    sig = sine(990, 0.10) * env_ad(int(SR * 0.10), 0.003, 0.13, 4.5)
    save("sfx_confirm", reverb_soft(sig, 0.2, 0.18), 0.40)

    # 3 拒绝：低而短的两下
    a = sine(233, 0.10) * env_ad(int(SR * 0.10), 0.005, 0.12, 3.5)
    b = sine(196, 0.12) * env_ad(int(SR * 0.12), 0.005, 0.14, 3.5)
    sig = np.zeros(int(SR * 0.22))
    sig[: len(a)] += a * 0.5
    off = int(SR * 0.08)
    sig[off: off + len(b)] += b * 0.45
    save("sfx_deny", reverb_soft(sig, 0.15, 0.2), 0.34)

    # 4 扫描：柔和上扫 + 一点点空气
    dur = 0.75
    n = int(SR * dur)
    f = np.linspace(280, 760, n)
    sig = sine(f, dur) * env_ad(n, 0.02, 0.6, 2.2)
    air = soft_noise(dur, 1400) * env_ad(n, 0.05, 0.35, 2.6) * 0.35
    save("sfx_scan", reverb_soft(sig * 0.7 + air, 0.3, 0.35), 0.36)

    # 5 命中：短促闷响（不是噪声爆）
    n = int(SR * 0.07)
    sig = sine(150, 0.07) * env_ad(n, 0.002, 0.06, 7) * 0.8
    sig += soft_noise(0.07, 900) * env_ad(n, 0.002, 0.05, 8) * 0.5
    save("sfx_hit", sig, 0.26)

    # 6 步枪：低频闷击 + 气声
    n = int(SR * 0.09)
    thump = sine(np.linspace(120, 62, n), 0.09) * env_ad(n, 0.001, 0.07, 9)
    air = soft_noise(0.09, 1600) * env_ad(n, 0.001, 0.05, 10)
    save("sfx_rifle", thump * 0.8 + air * 0.35, 0.30)

    # 7 炮击：更低的轰
    n = int(SR * 0.42)
    thump = sine(np.linspace(88, 38, n), 0.42) * env_ad(n, 0.004, 0.30, 4.2)
    air = soft_noise(0.42, 800) * env_ad(n, 0.004, 0.22, 4.5)
    save("sfx_cannon", reverb_soft(thump * 0.9 + air * 0.4, 0.28, 0.35), 0.42)

    # 8 爆炸
    n = int(SR * 0.75)
    boom = sine(np.linspace(62, 28, n), 0.75) * env_ad(n, 0.005, 0.5, 3.4)
    rumble = soft_noise(0.75, 520) * env_ad(n, 0.006, 0.42, 3.2)
    save("sfx_explosion", reverb_soft(boom * 0.9 + rumble * 0.55, 0.34, 0.55), 0.44)

    # 9 大爆炸
    n = int(SR * 1.3)
    boom = sine(np.linspace(48, 22, n), 1.3) * env_ad(n, 0.008, 0.95, 2.8)
    rumble = soft_noise(1.3, 380) * env_ad(n, 0.01, 0.8, 2.6)
    save("sfx_explosion_big", reverb_soft(boom * 0.9 + rumble * 0.6, 0.4, 0.9), 0.46)

    # 10 干扰：轻微失谐的嗡鸣（不刺耳）
    dur = 0.55
    n = int(SR * dur)
    t = t_axis(dur)
    wob = 1.0 + 0.02 * np.sin(2 * np.pi * 3.2 * t)
    sig = sine(320 * wob, dur) * 0.6 + sine(324 * wob, dur) * 0.4
    sig *= env_ad(n, 0.03, 0.45, 2.4)
    sig += soft_noise(dur, 900) * env_ad(n, 0.03, 0.3, 2.8) * 0.25
    save("sfx_jam", reverb_soft(sig, 0.25, 0.3), 0.30)

    # 11 阵亡通讯中断：下行音 + 沙沙
    dur = 0.85
    n = int(SR * dur)
    f = np.linspace(420, 190, n)
    sig = sine(f, dur) * env_ad(n, 0.01, 0.65, 2.6)
    sig += soft_noise(dur, 1200) * env_ad(n, 0.02, 0.5, 2.4) * 0.35
    save("sfx_death_signal", reverb_soft(sig, 0.32, 0.45), 0.34)

    # 12 警报：两个柔和的交替音
    dur = 0.7
    n = int(SR * dur)
    t = t_axis(dur)
    gate = 0.5 + 0.5 * np.sin(2 * np.pi * 2.0 * t - np.pi / 2)
    sig = sine(392, dur) * gate * 0.6 + sine(294, dur) * (1 - gate) * 0.5
    sig *= env_ad(n, 0.03, 0.6, 2.2)
    save("sfx_alarm", reverb_soft(sig, 0.28, 0.4), 0.32)

    # 13 波次开始：低频渐强
    dur = 0.85
    n = int(SR * dur)
    swell = np.clip(np.linspace(0, 1, n) ** 1.6, 0, 1)
    sig = (sine(110, dur) * 0.7 + sine(165, dur) * 0.3) * swell
    sig *= np.exp(-np.linspace(0, 4, n) * 0.6)
    save("sfx_wave", reverb_soft(sig, 0.3, 0.5), 0.36)

    # 14 UI 点击：极轻的一点
    n = int(SR * 0.045)
    sig = sine(1150, 0.045) * env_ad(n, 0.001, 0.03, 9) * 0.6
    save("sfx_ui", sig, 0.22)

    # 15 无线电 开 / 关
    for nm, rising in (("sfx_radio_open", True), ("sfx_radio_close", False)):
        dur = 0.16
        n = int(SR * dur)
        f = np.linspace(420, 700, n) if rising else np.linspace(700, 420, n)
        sig = sine(f, dur) * env_ad(n, 0.006, 0.12, 4) * 0.6
        sig += soft_noise(dur, 2200) * env_ad(n, 0.006, 0.08, 5) * 0.35
        save(nm, reverb_soft(sig, 0.2, 0.15), 0.26)

    # 16 环境（音乐关闭时不播放，保留文件）
    dur = 8.0
    n = int(SR * dur)
    t = t_axis(dur)
    base = soft_noise(dur, 240) * 0.5
    hum = sine(46, dur) * 0.10 + sine(92, dur) * 0.04
    pulse = 0.7 + 0.3 * np.sin(2 * np.pi * 0.11 * t)
    save("amb_drone", (base + hum) * pulse, 0.30)

    # 17 紧张音床（音乐关闭时不播放）
    dur = 12.0
    n = int(SR * dur)
    t = t_axis(dur)
    layers = np.zeros(n)
    for f, a in ((55, 0.45), (82.5, 0.26), (110, 0.16), (164.8, 0.08)):
        layers += sine(f, dur) * a
    layers *= 0.62 + 0.38 * np.sin(2 * np.pi * 0.05 * t)
    save("mus_dread", layers * 0.8, 0.28)

    # 18 脉冲点亮
    dur = 0.45
    n = int(SR * dur)
    f = np.linspace(340, 820, n)
    sig = sine(f, dur) * env_ad(n, 0.008, 0.32, 3.0)
    save("sfx_pulse", reverb_soft(sig, 0.3, 0.3), 0.34)

    print("完成。")


if __name__ == "__main__":
    main()
