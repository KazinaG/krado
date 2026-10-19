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
   items=[("Large","4 × 2","Big high-resolution displays"),("Medium","2 × 2","Typical desktop monitors"),
          ("Small","2 × 1","MacBook screens"),("Very small","1 × 1","Small or low-res screens"),("Portrait","1 × 2","Vertical monitors")],
   foot="Ultrawide monitors get 4 × 1 or 4 × 2. Short portrait screens stay 1 × 1.", font=(INTER,INTER)),
 "ja":dict(title="画面に合わせたマス目", sub="画面の大きさから分け方を自動で決めます。設定は不要です。",
   items=[("大きい画面","4 × 2","高解像度の大型ディスプレイ"),("中くらい","2 × 2","一般的なデスクトップ用モニター"),
          ("小さい画面","2 × 1","MacBook の画面"),("とても小さい","1 × 1","小型・低解像度の画面"),("縦置き","1 × 2","縦向きのモニター")],
   foot="ウルトラワイドは 4 × 1 または 4 × 2。高さの足りない縦置き画面は 1 × 1 です。", font=(CJKB,CJK)),
}
def rr(d,r,rad,fill,outline=None,width=0): d.rounded_rectangle([v*S for v in r],radius=rad*S,fill=fill,outline=outline,width=width*S)
for lang,t in TEXT.items():
    im=Image.new("RGB",(W*S,H*S)); d=ImageDraw.Draw(im)
    for y in range(H*S):
        u=y/(H*S); d.line([(0,y),(W*S,y)],fill=tuple(int(a+(b-a)*u) for a,b in zip(BG0,BG1)))
    bold,reg=t["font"]
    d.text((64*S,52*S),t["title"],font=F(bold,40,700),fill=(255,255,255))
    d.text((64*S,110*S),t["sub"],font=F(reg,19,450),fill=(186,200,218))
    specs=[(4,2,(200,128)),(2,2,(200,128)),(2,1,(176,112)),(1,1,(150,96)),(1,2,(96,160))]
    slot=(W-128)/5; base=380
    for i,((c,r,(sw,sh)),(name,grid,ex)) in enumerate(zip(specs,t["items"])):
        cx=64+slot*i+slot/2
        x0,y0=cx-sw/2,base-sh
        rr(d,(x0-8,y0-8,x0+sw+8,y0+sh+8),12,BEZEL); rr(d,(x0,y0,x0+sw,y0+sh),5,SCREEN)
        pad=5; cw=(sw-pad*(c+1))/c; ch=(sh-pad*(r+1))/r
        for ci in range(c):
            for ri in range(r):
                a=x0+pad+ci*(cw+pad); b=y0+pad+ri*(ch+pad)
                rr(d,(a,b,a+cw,b+ch),5,MINT if (ci,ri)==(0,0) else CELL)
        d.rectangle([(cx-10)*S,(base+8)*S,(cx+10)*S,(base+22)*S],fill=BEZEL)
        rr(d,(cx-34,base+20,cx+34,base+27),3,BEZEL)
        for txt,f,col,y in [(name,F(bold,20,650),(255,255,255),base+46),(grid,F(bold,30,750),MINT,base+76),(ex,F(reg,15,450),(186,200,218),base+118)]:
            w=d.textlength(txt,font=f)/S; d.text(((cx-w/2)*S,y*S),txt,font=f,fill=col)
    d.text((64*S,(H-62)*S),t["foot"],font=F(reg,17,450),fill=(186,200,218))
    name="layouts.png" if lang=="en" else "layouts.ja.png"
    im.resize((W,H),Image.LANCZOS).save(f"docs/assets/{name}")
print("ok")
