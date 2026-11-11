// broken.frag — deliberately invalid shader for the error demonstration (-showcaseInjectShaderError YES).
precision mediump float;
out vec4 color;
void main() {
    color = vec4(undefinedSymbol, 1.0);
}
