// CI runner only. Image representations and mean Rec.709 luminance of a small RGB raster.
import Foundation
import CoreGraphics
import ImageIO
guard CommandLine.arguments.count > 1, let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL,nil) else { exit(1) }
print("type",CGImageSourceGetType(src) as Any,"image count",CGImageSourceGetCount(src))
for i in 0..<CGImageSourceGetCount(src) {
 print("representation",i,CGImageSourceCopyPropertiesAtIndex(src,i,nil) as Any)
 guard let img = CGImageSourceCreateImageAtIndex(src,i,nil) else { continue }
 var p = [UInt8](repeating:0,count:64*64*4)
 p.withUnsafeMutableBytes { raw in
  guard let c = CGContext(data:raw.baseAddress,width:64,height:64,bitsPerComponent:8,bytesPerRow:256,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
  c.draw(img,in:CGRect(x:0,y:0,width:64,height:64))
 }
 var total = 0.0
 for n in stride(from:0,to:p.count,by:4) {
  let linear = (0..<3).map { channel -> Double in
   let v = Double(p[n+channel])/255
   return v <= 0.04045 ? v/12.92 : pow((v+0.055)/1.055,2.4)
  }
  total += linear[0]*0.2126+linear[1]*0.7152+linear[2]*0.0722
 }
 print("mean linear luminance",total/4096)
}
