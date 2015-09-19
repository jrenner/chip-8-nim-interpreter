import sdl2, sdl2/gfx
import chip8

discard sdl2.init(INIT_EVERYTHING)

var
    window: WindowPtr
    render: RendererPtr

window = createWindow("SDL Skeleton", 100, 100, 1280,640, SDL_WINDOW_SHOWN)
render = createRenderer(window, -1, Renderer_Accelerated or Renderer_PresentVsync or Renderer_TargetTexture)
const GFX_SCALE = 20

var
    evt = sdl2.defaultEvent
    fpsman: FpsManager
fpsman.init

# Create texture that stores frame buffer

var texture: TexturePtr = createTexture(render,
    SDL_PIXELFORMAT_RGB332,
    SDL_TEXTUREACCESS_STREAMING,
    64, 32)


# SDL_Texture* sdlTexture = SDL_CreateTexture(renderer,
#     SDL_PIXELFORMAT_ARGB8888,
#     SDL_TEXTUREACCESS_STREAMING,
#     64, 32);

type
    DisplayObj = object
    Display* = ref DisplayObj

proc drawPixel*(d: Display, x: int, y: int) =
    let r = 255'u8
    let g = 255'u8
    let b = 255'u8
    let a = 255'u8
    let x1 = int16(x*GFX_SCALE)
    let y1 = int16(y*GFX_SCALE)
    let x2 = int16((x+1)*GFX_SCALE)
    let y2 = int16((y+1)*GFX_SCALE)
    #rectangleRGBA(render, x1, y1, x2, y2, r, g, b, a)
    render.boxRGBA(x1, y1, x2, y2, r, g, b, a)

proc draw*(d: Display) =
    render.present
    render.setDrawColor 0,0,0,255
    render.clear

proc processKeys*(): string =
    while pollEvent(evt):
        case evt.kind
        of KeyDown:
            let p = cast[KeyboardeventPtr](addr evt)
            case p.keysym.scancode
            of SDL_SCANCODE_P:
                return "pause"
            of SDL_SCANCODE_SPACE:
                return "space"
            of SDL_SCANCODE_Q:
                return "quit"
            else:
                discard
        else:
            discard

