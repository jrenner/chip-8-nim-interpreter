import sdl2, sdl2/gfx

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

proc processKeys*(): seq[(EventType, string)] =
    result = @[]
    while pollEvent(evt):
        var out_str = ""
        case evt.kind
        of KeyDown, KeyUp:
            let p = cast[KeyboardeventPtr](addr evt)
            case p.keysym.scancode
            of SDL_SCANCODE_P:
                out_str = "pause"
            of SDL_SCANCODE_SPACE:
                out_str = "space"
            of SDL_SCANCODE_ESCAPE:
                out_str = "quit"
            of SDL_SCANCODE_1:
              out_str = "1"
            of SDL_SCANCODE_2:
              out_str = "2"
            of SDL_SCANCODE_3:
              out_str = "3"
            of SDL_SCANCODE_4:
              out_str = "4"

            of SDL_SCANCODE_Q:
              out_str = "Q"
            of SDL_SCANCODE_W:
              out_str = "W"
            of SDL_SCANCODE_E:
              out_str = "E"
            of SDL_SCANCODE_R:
              out_str = "R"

            of SDL_SCANCODE_A:
              out_str = "A"
            of SDL_SCANCODE_S:
              out_str = "S"
            of SDL_SCANCODE_D:
              out_str = "D"
            of SDL_SCANCODE_F:
              out_str = "F"

            of SDL_SCANCODE_Z:
              out_str = "Z"
            of SDL_SCANCODE_X:
              out_str = "X"
            of SDL_SCANCODE_C:
              out_str = "C"
            of SDL_SCANCODE_V:
              out_str = "V"

            else:
                discard
            let event_res = (evt.kind, out_str)
            result.add(event_res)
        else:
            discard

