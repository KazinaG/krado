from PIL import Image, ImageDraw, ImageFont
S=2; W,H=1280,640
INTER="/usr/share/fonts/truetype/sand-box/google/Inter/Inter-VariableFont_opsz,wght.ttf"
CJKB="/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc"; CJK="/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"
BG0,BG1=(16,26,48),(14,52,64); BEZEL=(78,96,120); SCREEN=(28,38,58); CELL=(236,238,242); MINT=(94,242,214)
def F(p,s,w=None):
    f=ImageFont.truetype(p,s*S)
    if w and p==INTER:
        try: f.set_variation_by_axes([14,w])
        except Exception: pass
    return f
TEXT={
 "en":dict(title="A grid that fits each screen", sub="krado picks the split from the screen's size. No setup.",
   items=[("MacBook Air","2 × 1","Default size"),("4K","2 × 2","Default size"),("6K","3 × 2","Default size"),
          ("4K","4 × 2","Native size"),("8K","8 × 4","Native size"),("Portrait 4K","2 × 3","Native size"),("Ultrawide","4 × 2","3440 × 1440")],
   foot="Zones stay at least about 900 × 1000 pt where possible, never tiny. MacBooks are never split top and bottom.", font=(INTER,INTER)),
 "ja":dict(title="画面に合わせたマス目", sub="画面の大きさから分け方を自動で決めます。設定は不要です。",
   items=[("MacBook Air","2 × 1","標準の大きさ"),("4K","2 × 2","標準の大きさ"),("6K","3 × 2","標準の大きさ"),
          ("4K","4 × 2","等倍"),("8K","8 × 4","等倍"),("縦置き 4K","2 × 3","等倍"),("ウルトラワイド","4 × 2","3440 × 1440")],
   foot="画面が大きいほど均等に細かく分けますが、マスが小さくなりすぎることはありません。MacBook は上下に分けません。", font=(CJKB,CJK)),
}
def rr(d,r,rad,fill,outline=None,width=0): d.rounded_rectangle([v*S for v in r],radius=rad*S,fill=fill,outline=outline,width=width*S)
for lang,t in TEXT.items():
    im=Image.new("RGB",(W*S,H*S)); d=ImageDraw.Draw(im)
    for y in range(H*S):
        u=y/(H*S); d.line([(0,y),(W*S,y)],fill=tuple(int(a+(b-a)*u) for a,b in zip(BG0,BG1)))
    bold,reg=t["font"]
    d.text((64*S,52*S),t["title"],font=F(bold,40,700),fill=(255,255,255))
    d.text((64*S,110*S),t["sub"],font=F(reg,19,450),fill=(186,200,218))
    specs=[(2,1,(124,80)),(2,2,(132,76)),(3,2,(136,78)),(4,2,(132,76)),(8,4,(140,80)),(2,3,(84,148)),(4,2,(150,64))]
    slot=(W-128)/7; base=380
    for i,((c,r,(sw,sh)),(name,grid,ex)) in enumerate(zip(specs,t["items"])):
        cx=64+slot*i+slot/2
        x0,y0=cx-sw/2,base-sh
        rr(d,(x0-8,y0-8,x0+sw+8,y0+sh+8),12,BEZEL); rr(d,(x0,y0,x0+sw,y0+sh),5,SCREEN)
        pad=3 if c>4 else 5; cw=(sw-pad*(c+1))/c; ch=(sh-pad*(r+1))/r
        for ci in range(c):
            for ri in range(r):
                a=x0+pad+ci*(cw+pad); b=y0+pad+ri*(ch+pad)
                rr(d,(a,b,a+cw,b+ch),2 if c>4 else 5,MINT if (ci,ri)==(0,0) else CELL)
        d.rectangle([(cx-10)*S,(base+8)*S,(cx+10)*S,(base+22)*S],fill=BEZEL)
        rr(d,(cx-34,base+20,cx+34,base+27),3,BEZEL)
        for txt,f,col,y in [(name,F(bold,18,650),(255,255,255),base+46),(grid,F(bold,28,750),MINT,base+74),(ex,F(reg,14,450),(186,200,218),base+114)]:
            w=d.textlength(txt,font=f)/S; d.text(((cx-w/2)*S,y*S),txt,font=f,fill=col)
    d.text((64*S,(H-62)*S),t["foot"],font=F(reg,16,450),fill=(186,200,218))
    name="layouts.png" if lang=="en" else "layouts.ja.png"
    im.resize((W,H),Image.LANCZOS).save(f"docs/assets/{name}")
print("ok")
