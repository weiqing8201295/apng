import fs from '@ohos.file.fs'
import {GlobalContext} from '../../common/GlobalContext'
import parseAPNG from "./parser"
import {APNG,Frame} from "./structs"

type File = fs.File;

function  getContext():Context{
  return GlobalContext.getContext().getObject('MainContext') as Context;
}

class APngManager{
  constructor() {
  }
  getAPNGInstance(buffer:Uint8Array):APNG{
    let apng = {} as APNG;
    apng = parseAPNG(buffer);
    return apng;
  }

  async getResource(resource:Resource):Promise<Uint8Array>{
    let buffer = new Uint8Array();
    const resourceManager = getContext().resourceManager;
    buffer = await resourceManager.getMediaContent(resource.id);
    return buffer;
  }

  async open(url:string):Promise<File>{
    let file = {} as File;
    file = await fs.open(url);
    return file;
  }

}
export default  APngManager;