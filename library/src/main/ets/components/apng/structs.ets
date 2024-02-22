/**
 * @property {number} currFrameNumber
 * @property {Frame} currFrame
 * @property {boolean} paused
 * @property {boolean} ended
 */
export class APNG {
  isAPNG = true;
  /** @type {number} */
  width = 0;
  /** @type {number} */
  height = 0;
  /** @type {number} */
  numPlays = 0;
  /** @type {number} */
  playTime = 0;
  /** @type {Frame[]} */
  frames:Frame[] = [];
}

export class Frame {
  /** @type {number} */
  left = 0;
  /** @type {number} */
  top = 0;
  /** @type {number} */
  width = 0;
  /** @type {number} */
  height = 0;
  /** @type {number} */
  delay = 0;
  /** @type {number} */
  disposeOp = 0;
  /** @type {number} */
  blendOp = 0;

  dataParts:Uint8Array[] = [];

  imageBuffer:Uint8Array[] = [];
}
