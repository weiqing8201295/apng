import APngManager from "./src/main/ets/components/apng/manager"
import bufferUtil from '@ohos.buffer';
import {APNG,Frame} from "./src/main/ets/components/apng/structs"

function typedArrayConcat(buffer1: ArrayBuffer | Uint8Array, buffer2: ArrayBuffer | Uint8Array) : ArrayBuffer {
  const u1 = new Uint8Array(buffer1);
  const u2 = new Uint8Array(buffer2);
  const length = u1.byteLength+u2.byteLength;
  const buffer = new ArrayBuffer(length);
  const uintBuffer = new Uint8Array(buffer);
  uintBuffer.set(u1,0);
  uintBuffer.set(u2,buffer1.byteLength);
  return uintBuffer.buffer;
}

const defaultSpeed = 1;
@Component
export default struct APng{
  private settings:RenderingContextSettings = new RenderingContextSettings(true);
  private context:CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  @Prop src:Resource;
  @Prop speedRate:number = defaultSpeed;
  @State imageSrc: string | PixelMap | Resource = '';
  @State @Watch('imageArrWatchHandle') imageArr:Array<string> = [];
  @State currentImage:string = '';
  @State styleInfo:Array<Object> = [];
  @State _numPlays:number = 0;
  private prevFrameData: ImageData | null = null;
  private prevFrame:Frame = new Frame();
  scroller:Scroller = new Scroller();
  @State count:number = 0;
  @State frameTime:number = 100 / this.speedRate;

  aboutToAppear(){
    this.init();
  }

  getAllImage:(allImages:Array<string>) => void=()=>{};

  loop(c:number,max:number){
    let frameInfo = this.styleInfo[this.count] as Frame;
    this.frameTime = frameInfo.delay == 0?100:frameInfo.delay/this.speedRate;
    let count = this.count;

    setInterval(()=>{
      count >= (max-1)?count=0:count++;
      this.count = count;
      this.currentImage = this.imageArr[count];
      let img:ImageBitmap = new ImageBitmap(this.currentImage);
      let frameStyle = this.styleInfo[count] as Frame;

      if(count===0){
        this.context.clearRect(0,0,frameStyle.width,frameStyle.height);
        this.prevFrameData = null;
        if(frameStyle.disposeOp === 2) frameStyle.disposeOp = 1;
      }

      if(this.prevFrame && this.prevFrame.disposeOp == 1){
        this.context.clearRect(this.prevFrame.left,this.prevFrame.top,this.prevFrame.width,this.prevFrame.height);
      }else if(this.prevFrame && this.prevFrame.disposeOp == 2){
        this.context.putImageData(this.prevFrameData,this.prevFrame.left,this.prevFrame.top);
      }

      let frame = frameStyle;
      this.prevFrame = frame;
      this.prevFrameData = null;
      if(frame.disposeOp == 2){
        this.prevFrameData = this.context.getImageData(frame.left,frame.top,frame.width,frame.height);
      }
      if(frame.blendOp == 0){
        this.context.clearRect(frame.left,frame.top,frame.width,frame.height);
      }
      this.context.imageSmoothingEnabled = false;
      this.context.drawImage(img,frame.left,frame.top,frame.width,frame.height);
    },this.frameTime)
  }

  imageArrWatchHandle(){
    const imageArr = this.imageArr;
    this.getAllImage(imageArr);
    if(!imageArr.length){
      return;
    }
    if(imageArr.length == 1){
      this.currentImage = imageArr[0];
      return;
    }
    this.loop(this.count,imageArr.length);
  }

  async init(){
    const apngManager = new APngManager();

    if(this.src){
      const buffer = await apngManager.getResource(this.src);
      const apng = apngManager.getAPNGInstance(buffer) as APNG;
      if(apng.frames.length){
        let imagePixelArr:Array<string> = [];
        this.styleInfo = apng.frames;
        apng.frames.forEach((item)=>{
          const bufferArr = item.imageBuffer;
          const buffer = bufferArr.reduce((rst,item)=>{
            return typedArrayConcat(rst,item)
          },new ArrayBuffer(0))
          const b = bufferUtil.from(buffer);
          const pbase64 = `data:image/png;base64,${b.toString('base64')}`;
          imagePixelArr.push(pbase64);

          if(imagePixelArr.length === apng.frames.length){
            this.imageArr = imagePixelArr;
          }
        })
      }
    }
  }

  build(){
    Flex({direction:FlexDirection.Column,alignItems:ItemAlign.Center,justifyContent:FlexAlign.Center}) {
      Canvas(this.context)
        .width('100%')
        .height('100%')
        .backgroundColor('#ffff00')
    }
    .width('100%')
    .height('100%')
  }
}
export {GlobalContext} from './src/main/ets/common/GlobalContext';