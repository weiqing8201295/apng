import crc32 from "./crc32"
import {APNG,Frame} from "./structs"

const errNotPNG = new Error('Not a PNG');
const errNotAPNG = new Error('Not an animated PNG');

export function isNotPNG(err:Error){
  return err = errNotPNG;
}

export function isNotAPNG(err:Error){
  return err = errNotAPNG;
}

// '\x89PNG\x0d\x0a\x1a\x0a'
const PNGSignature = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

/**
 * Parse APNG data
 * @param {ArrayBuffer} buffer
 * @return {APNG|Error}
 */
export default function parseAPNG(buffer:Uint8Array) {
  const bytes = buffer;
  let apng = new APNG();

  for (let i = 0; i < PNGSignature.byteLength; i++) {
    if(bytes[i]!==PNGSignature[i]){
      apng.isAPNG = false;
      throw errNotAPNG;
    }
  }

  let isAnimated = false;

  eachChunk(bytes, type => !(isAnimated = (type === 'acTL')));
  if (!isAnimated) {
    apng.isAPNG = false;
    throw errNotAPNG;
  }

  let preDataParts:Uint8Array[] = [];
  let postDataParts:Uint8Array[] = [];
  let headerDataBytes = new Uint8Array();
  let frame = new Frame();
  let frameNumber = 0;


  eachChunk(bytes, (type :string, bytes:Uint8Array, off:number, length:number) => {
    const dv = new DataView(bytes.buffer);
    switch (type) {
      case 'IHDR':
        headerDataBytes = bytes.subarray(off + 8, off + 8 + length);
        apng.width = dv.getUint32(off + 8);
        apng.height = dv.getUint32(off + 12);
        break;
      case 'acTL':
        apng.numPlays = dv.getUint32(off + 8 + 4);
        break;
      case 'fcTL':
        if (frame) {
          apng.frames.push(frame);
          frameNumber++;
        }
        frame = new Frame();
        frame.width = dv.getUint32(off + 8 + 4);
        frame.height = dv.getUint32(off + 8 + 8);
        frame.left = dv.getUint32(off + 8 + 12);
        frame.top = dv.getUint32(off + 8 + 16);
        let delayN = dv.getUint16(off + 8 + 20);
        let delayD = dv.getUint16(off + 8 + 22);
        if (delayD === 0) {
          delayD = 100;
        }
        frame.delay = 1000 * delayN / delayD;
      // https://bugzilla.mozilla.org/show_bug.cgi?id=125137
      // https://bugzilla.mozilla.org/show_bug.cgi?id=139677
      // https://bugzilla.mozilla.org/show_bug.cgi?id=207059
        if (frame.delay <= 10) {
          frame.delay = 100;
        }
        apng.playTime += frame.delay;
        frame.disposeOp = dv.getUint8(off + 8 + 24);
        frame.blendOp = dv.getUint8(off + 8 + 25);
        frame.dataParts = [];
        if (frameNumber === 0 && frame.disposeOp === 2) {
          frame.disposeOp = 1;
        }
        break;
      case 'fdAT':
        if (frame) {
          frame.dataParts.push(bytes.subarray(off + 8 + 4, off + 8 + length));
        }
        break;
      case 'IDAT':
        if (frame) {
          frame.dataParts.push(bytes.subarray(off + 8, off + 8 + length));
        }
        break;
      case 'IEND':
        postDataParts.push(subBuffer(bytes, off, 12 + length));
        break;
      default:
        preDataParts.push(subBuffer(bytes, off, 12 + length));
    }
  });

  if (frame) {
    apng.frames.push(frame);
  }

  if (apng.frames.length == 0) {
    apng.isAPNG = false;
    throw errNotAPNG;
  }

  apng.frames.forEach(frame => {
    let bb:Array<Uint8Array> = [];
    bb.push(PNGSignature);
    headerDataBytes.set(makeDWordArray(frame.width), 0);
    headerDataBytes.set(makeDWordArray(frame.height), 4);
    bb.push(makeChunkBytes('IHDR', headerDataBytes));
    bb.push(...preDataParts);
    frame.dataParts.forEach(p => bb.push(makeChunkBytes('IDAT', p)));
    bb.push(...postDataParts);
    frame.imageBuffer = bb;
    let str = `${bb.length} /`;
    bb.forEach((item,index)=>{
      str += `/ ${index}-${item.byteLength}`
    })
    frame.imageBuffer = bb;
    frame.dataParts = [];
    bb = [];
  });

  return apng;
}

/**
 * @param {Uint8Array} bytes
 * @param {function(string, Uint8Array, int, int): boolean} callback
 */
type eachChunkCb = (type:string,bytes:Uint8Array,off:number,length:number) => void | boolean;
function eachChunk(bytes:Uint8Array, callback:eachChunkCb) {
  const dv = new DataView(bytes.buffer);
  let off = 8, type='', length=0, res=false;
  do {
    length = dv.getUint32(off);
    type = readString(bytes, off + 4, 4);
    res = callback(type, bytes, off, length) as boolean;
    off += 12 + length;
  } while (res !== false && type != 'IEND' && off < bytes.length);
}

/**
 *
 * @param {Uint8Array} bytes
 * @param {number} off
 * @param {number} length
 * @return {string}
 */
function readString(bytes:Uint8Array, off:number, length:number) {
  const chars = bytes.subarray(off, off + length).slice();
  return String.fromCharCode(...chars);
}

/**
 *
 * @param {string} x
 * @return {Uint8Array}
 */
function makeStringArray(x:string) {
  const res = new Uint8Array(x.length);
  for (let i = 0; i < x.length; i++) {
    res[i] = x.charCodeAt(i);
  }
  return res;
}


/**
 * @param {Uint8Array} bytes
 * @param {int} start
 * @param {int} length
 * @return {Uint8Array}
 */
function subBuffer(bytes:Uint8Array, start:number, length:number) {
  const a = new Uint8Array(length);
  a.set(bytes.subarray(start, start + length));
  return a;
}

/**
 * @param {string} type
 * @param {Uint8Array} dataBytes
 * @return {Uint8Array}
 */
function makeChunkBytes (type:string, dataBytes:Uint8Array) {
  const crcLen = type.length + dataBytes.length;
  const bytes = new Uint8Array(crcLen + 8);
  const dv = new DataView(bytes.buffer);

  dv.setUint32(0, dataBytes.length);
  bytes.set(makeStringArray(type), 4);
  bytes.set(dataBytes, 8);
  let crc = crc32(bytes, 4, crcLen);
  dv.setUint32(crcLen + 4, crc);
  return bytes;
};

function makeDWordArray (x:number) {
  return new Uint8Array([(x >>> 24) & 0xff, (x >>> 16) & 0xff, (x >>> 8) & 0xff, x & 0xff]);
};
