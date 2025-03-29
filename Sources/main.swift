import class CoreGraphics.CGColorSpace
import func CoreGraphics.CGColorSpaceCreateDeviceRGB
import struct CoreGraphics.CGSize
import class CoreImage.CIContext
import struct CoreImage.CIFormat
import class CoreImage.CIImage
import struct Foundation.Data
import class Foundation.ProcessInfo
import struct Foundation.URL

enum PngToCsvErr: Error {
  case unableToLoad(String)
  case invalidArgument(String)
  case invalidBuffer
  case unimplemented(String)
}

typealias UrlToImage = (URL) -> Result<CIImage, Error>

func UrlToImg(_ url: URL) -> Result<CIImage, Error> {
  let oimg: CIImage? = CIImage(contentsOf: url)
  guard let img = oimg else {
    return .failure(PngToCsvErr.unableToLoad("rejected url: \( url )"))
  }
  return .success(img)
}

struct ImageRgba8 {
  public let img: CIImage

  public func size() -> CGSize { self.img.extent.size }

  public func width() -> Int { Int(self.size().width) }
  public func height() -> Int { Int(self.size().height) }

  public func rowBytes() -> Int { 4 * self.width() }

  public func byteCount() -> Int { self.rowBytes() * self.height() }

  public func format() -> CIFormat { .RGBA8 }
  public func color() -> CGColorSpace { CGColorSpaceCreateDeviceRGB() }

  public func ToData(ictx: CIContext) -> Result<Data, Error> {
    var dat: Data = Data(count: self.byteCount())
    let res: Result<(), Error> = dat.withUnsafeMutableBytes {
      let buf: UnsafeMutableRawBufferPointer = $0
      let oraw: UnsafeMutableRawPointer? = buf.baseAddress
      guard let raw = oraw else {
        return .failure(PngToCsvErr.invalidBuffer)
      }

      ictx.render(
        self.img,
        toBitmap: raw,
        rowBytes: self.rowBytes(),
        bounds: self.img.extent,
        format: self.format(),
        colorSpace: self.color()
      )
      return .success(())
    }
    return res.map {
      _ = $0
      return dat
    }
  }
}

struct RawImage {
  public let data: Data
  public let width: Int
  public let height: Int
}

typealias ImageToData = (CIImage) -> Result<RawImage, Error>

func ImgToDatRgbaNew8(ictx: CIContext = CIContext()) -> ImageToData {
  return {
    let img: CIImage = $0
    let i8: ImageRgba8 = ImageRgba8(img: img)
    let rdat: Result<Data, _> = i8.ToData(ictx: ictx)

    return rdat.map {
      let dat: Data = $0
      return RawImage(
        data: dat,
        width: i8.width(),
        height: i8.height()
      )
    }
  }
}

typealias IntegerToString = (UInt8) -> String

func IntToStr(_ i: UInt8) -> String { "\( i )" }

typealias DataToLineToStdout = (Data) -> Result<(), Error>

func DatToLineToStdoutNew(
  i2s: @escaping IntegerToString = IntToStr,
  terminator: String = ","
) -> DataToLineToStdout {
  return {
    let line: Data = $0
    for i in line {
      let s: String = i2s(i)
      print(s, terminator: terminator)
    }
    print()
    return .success(())
  }
}

typealias DataToLinesToStdout = (Data) -> Result<(), Error>

func Dat2LinesToStdoutNew(
  width: Int,
  height: Int,
  d2l: @escaping DataToLineToStdout = DatToLineToStdoutNew()
) -> DataToLinesToStdout {
  return {
    let rows: Data = $0
    let rowSize: Int = 4 * width
    for y in 0..<height {
      let start: Int = y * rowSize
      let end: Int = start + rowSize
      let dat: Data = rows[start..<end]
      let res: Result<(), _> = d2l(dat)
      switch res {
      case .success: continue
      case .failure(let err): return .failure(err)
      }
    }
    return .success(())  // todo
  }
}

func EnvValByKey(_ key: String) -> Result<String, Error> {
  let values: [String: String] = ProcessInfo.processInfo.environment
  let oval: String? = values[key]
  guard let val = oval else {
    return .failure(PngToCsvErr.invalidArgument("env var \( key ) missing"))
  }
  return .success(val)
}

func StringToUrl(_ s: String) -> URL { URL(fileURLWithPath: s) }

func Compose<T, U, V>(
  _ f: @escaping (T) -> Result<U, Error>,
  _ g: @escaping (U) -> Result<V, Error>
) -> (T) -> Result<V, Error> {
  return {
    let t: T = $0
    let ru: Result<U, _> = f(t)
    return ru.flatMap {
      let u: U = $0
      return g(u)
    }
  }
}

func ipngUrl() -> Result<URL, Error> {
  Compose(EnvValByKey, { .success(StringToUrl($0)) })("ENV_I_PNG_FILENAME")
}

func sub() -> Result<(), Error> {
  let url2img: UrlToImage = UrlToImg
  let img2dat: ImageToData = ImgToDatRgbaNew8()

  let pimg: Result<CIImage, _> = ipngUrl().flatMap { return url2img($0) }
  let raw: Result<RawImage, _> = pimg.flatMap { return img2dat($0) }

  return raw.flatMap {
    let rimg: RawImage = $0
    let width: Int = rimg.width
    let height: Int = rimg.height
    let dat2lines2stdout: DataToLinesToStdout = Dat2LinesToStdoutNew(
      width: width,
      height: height
    )
    let dat: Data = rimg.data
    return dat2lines2stdout(dat)
  }
}

@main
struct PngToCsv {
  static func main() {
    do {
      try sub().get()
    } catch {
      print("\( error )")
    }
  }
}
