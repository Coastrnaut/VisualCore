// vc/spectral.glsl — VisualCore GLSL library: perceptual colour on the GPU (feature 210 (R02-F10) T-R02F10-006;
// FR-R02F10-002, FR-R02F10-004, FR-R02F10-011; research R1, R3, R13). The port of PerceptualColor and
// ColorVisionCondition (VisualCoreParameters): OKLab (Ottosson 2020, M1/M2 for linear sRGB, the exact inverses as
// float literals), a hue rotation in OKLCh that keeps L and C with the same 24-step chroma bisection into the sRGB
// gamut, and the Machado 2009 severity-1.0 colour-vision simulation. Every function takes and returns linear sRGB.
// Conditions: 0 normal, 1 protanopia, 2 deuteranopia, 3 tritanopia, 4 achromatopsia (Rec. 709 Y on every channel).
#ifndef VC_SPECTRAL_GLSL
#define VC_SPECTRAL_GLSL
highp vec3 vc_spectralCbrt(highp vec3 x) { return sign(x) * pow(abs(x), vec3(1.0 / 3.0)); }
highp vec3 vc_linearToOklab(highp vec3 c) {
    highp vec3 lms = vec3(dot(vec3(0.4122214708, 0.5363325363, 0.0514459929), c),
                          dot(vec3(0.2119034982, 0.6806995451, 0.1073969566), c),
                          dot(vec3(0.0883024619, 0.2817188376, 0.6299787005), c));
    highp vec3 r = vc_spectralCbrt(lms);
    return vec3(dot(vec3(0.2104542553, 0.7936177850, -0.0040720468), r),
                dot(vec3(1.9779984951, -2.4285922050, 0.4505937099), r),
                dot(vec3(0.0259040371, 0.7827717662, -0.8086757660), r));
}
highp vec3 vc_oklabToLinear(highp vec3 c) {
    highp vec3 r = vec3(dot(vec3(0.9999999985, 0.3963377922, 0.2158037581), c),
                        dot(vec3(1.0000000089, -0.1055613423, -0.0638541748), c),
                        dot(vec3(1.0000000547, -0.0894841821, -1.2914855379), c));
    highp vec3 lms = r * r * r;
    return vec3(dot(vec3(4.0767416613, -3.3077115904, 0.2309699287), lms),
                dot(vec3(-1.2684380041, 2.6097574007, -0.3413193963), lms),
                dot(vec3(-0.0041960865, -0.7034186145, 1.7076147009), lms));
}
// In-gamut test of an OKLCh colour (linear sRGB within the tolerance per channel). The CPU tolerance is 1e-12, below
// float resolution; 1e-6 is the float equivalent.
bool vc_spectralInGamut(highp float l, highp float chroma, highp float h) {
    highp vec3 c = vc_oklabToLinear(vec3(l, chroma * cos(h), chroma * sin(h)));
    return all(greaterThanEqual(c, vec3(-1e-6))) && all(lessThanEqual(c, vec3(1.0 + 1e-6)));
}
// Rotates the OKLCh hue of a linear colour by `radians`, keeping L and C, brings it into gamut by bisecting the
// chroma for exactly 24 steps at constant L and h, and clamps to 0…1. Greys (equal channels or C ≈ 0) are unchanged.
highp vec3 vc_hueRotate(highp vec3 linearRGB, highp float radians) {
    if (linearRGB.r == linearRGB.g && linearRGB.g == linearRGB.b) { return linearRGB; }
    highp vec3 lab = vc_linearToOklab(linearRGB);
    highp float chroma = length(lab.yz);
    if (chroma < 1e-7) { return linearRGB; }
    highp float tau = 6.283185307179586;
    highp float h = atan(lab.z, lab.y);
    if (h < 0.0) { h += tau; }
    h = mod(h + radians, tau);
    if (!vc_spectralInGamut(lab.x, chroma, h)) {
        highp float lo = 0.0, hi = chroma;
        for (int i = 0; i < 24; i++) {
            highp float mid = (lo + hi) / 2.0;
            if (vc_spectralInGamut(lab.x, mid, h)) { lo = mid; } else { hi = mid; }
        }
        chroma = lo;
    }
    return clamp(vc_oklabToLinear(vec3(lab.x, chroma * cos(h), chroma * sin(h))), 0.0, 1.0);
}
// Simulates a colour-vision condition on a linear colour: the 3×3 matrix (rows as in ColorVisionCondition.matrix),
// then each channel clamped to 0…1.
highp vec3 vc_simulateCVD(highp vec3 linearRGB, int condition) {
    highp vec3 c = linearRGB, r = c;
    if (condition == 1) {
        r = vec3(dot(vec3(0.152286, 1.052583, -0.204868), c), dot(vec3(0.114503, 0.786281, 0.099216), c),
                 dot(vec3(-0.003882, -0.048116, 1.051998), c));
    } else if (condition == 2) {
        r = vec3(dot(vec3(0.367322, 0.860646, -0.227968), c), dot(vec3(0.280085, 0.672501, 0.047413), c),
                 dot(vec3(-0.011820, 0.042940, 0.968881), c));
    } else if (condition == 3) {
        r = vec3(dot(vec3(1.255528, -0.076749, -0.178779), c), dot(vec3(-0.078411, 0.930809, 0.147602), c),
                 dot(vec3(0.004733, 0.691367, 0.303900), c));
    } else if (condition == 4) {
        r = vec3(dot(vec3(0.2126, 0.7152, 0.0722), c));
    }
    return clamp(r, 0.0, 1.0);
}
#endif
