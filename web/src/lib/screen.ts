// The phone is receive-only. No getUserMedia, getDisplayMedia, WebCodecs,
// secure-context requirement, or third-party ICE service is needed here.
import { reactive, watch } from 'vue'
import { onMessage, send, state as connection } from './connection'
import { releaseAll } from './input'
import type { DisplayInfo } from './protocol'
import { settings } from './settings'
import { ScreenImageAssembler, ScreenImageRenderer } from './screenImages'

export const screen = reactive({
  active: false,
  status: 'idle' as 'idle' | 'loading' | 'ready' | 'connecting' | 'live' | 'error',
  displays: [] as DisplayInfo[],
  message: '',
  needsPlay: false,
  canRequest: false,
  accessState: 'idle' as string,
  accessMessage: '',
  original: false,
})

let video: HTMLVideoElement | null = null
let picture: HTMLCanvasElement | null = null
let renderer: ScreenImageRenderer | null = null
let channel: RTCDataChannel | null = null
const images = new ScreenImageAssembler()
let peer: RTCPeerConnection | null = null
let request = 0
let streamId: number | null = null
let listId: number | null = null
let generation = 0
let heartbeat: ReturnType<typeof setInterval> | undefined
let timeout: ReturnType<typeof setTimeout> | undefined
let listTimeout: ReturnType<typeof setTimeout> | undefined
let disconnected: ReturnType<typeof setTimeout> | undefined
let cancelGathering: (() => void) | undefined
let accessId: number | null = null
let accessTimeout: ReturnType<typeof setTimeout> | undefined
let approvalRefresh: ReturnType<typeof setTimeout> | undefined

export function cancelAccessRequest() {
  if (accessId !== null) send({ t: 'displayAccessCancel', id: accessId })
  accessId = null
  clearTimeout(accessTimeout)
  clearTimeout(approvalRefresh)
  if (screen.accessState === 'pending') { screen.accessState = 'idle'; screen.accessMessage = '' }
}

export function requestScreenAccess() {
  if (!canView() || !connection.features.displayRequests || accessId !== null) return
  const id = ++request
  accessId = id
  screen.accessState = 'pending'
  screen.accessMessage = '请在 Mac 上批准屏幕镜像。此请求将在一分钟后过期。'
  if (!send({ t: 'displayAccessRequest', id })) { cancelAccessRequest(); screen.accessState = 'error'; return }
  accessTimeout = setTimeout(() => {
    if (accessId !== id) return
    cancelAccessRequest()
    screen.accessState = 'expired'
    screen.accessMessage = '访问请求已过期。请在 Mac 前有人时重新请求。'
  }, 65_000)
}

export const screenSupported = () => typeof RTCPeerConnection !== 'undefined'
export const selectedDisplay = () => screen.displays.find(display => display.id === settings.displayId)
const visible = () => screen.active && document.visibilityState === 'visible'
const canView = () => visible() && connection.status === 'connected' && !connection.paused

function closeStream(notify = true) {
  const wasViewing = streamId !== null || peer !== null
  generation++
  cancelGathering?.()
  cancelGathering = undefined
  clearInterval(heartbeat)
  clearTimeout(timeout)
  clearTimeout(disconnected)
  heartbeat = undefined
  timeout = undefined
  disconnected = undefined
  if (channel) { channel.onmessage = null; channel.onclose = null; channel.close(); channel = null }
  images.reset()
  renderer?.stop()
  renderer = null
  if (picture) { picture.width = 0; picture.height = 0 }
  const id = streamId
  streamId = null
  if (notify && id !== null) send({ t: 'displayStop', id })
  if (peer) {
    peer.ontrack = null
    peer.onconnectionstatechange = null
    peer.close()
    peer = null
  }
  if (video) {
    video.onplaying = null
    video.pause()
    const media = video.srcObject as MediaStream | null
    media?.getTracks().forEach(track => track.stop())
    video.srcObject = null
  }
  screen.needsPlay = false
  return wasViewing
}

export function stopViewing(message = '', notify = true) {
  const wasViewing = closeStream(notify)
  if (wasViewing || screen.active) releaseAll()
  screen.status = screen.displays.length ? 'ready' : 'idle'
  screen.message = message
}

function fail(message: string) {
  stopViewing(message)
  screen.status = 'error'
}

export function refreshDisplays() {
  if (listId !== null) return
  // Refreshing the list keeps a healthy view. The Mac ends the view itself
  // when the display being watched goes away.
  const viewing = streamId !== null && canView()
  if (!viewing) stopViewing()
  screen.canRequest = false
  clearTimeout(listTimeout)
  listId = null
  if (!canView()) return
  if (!screenSupported()) {
    fail('此浏览器无法接收实时画面。请尝试使用 Safari、Chrome、Firefox 或 Samsung Internet。')
    return
  }
  if (connection.features.display === undefined) {
    fail('请更新 Mac 上的 CmdPalm 以使用屏幕镜像。')
    return
  }
  if (!viewing) screen.status = 'loading'
  const id = ++request
  listId = id
  if (!send({ t: 'displays', id })) {
    listId = null
    fail('Mac 未连接。')
    return
  }
  listTimeout = setTimeout(() => {
    if (listId !== id) return
    listId = null
    if (streamId === null) fail('Mac 没有响应。请检查其连接，然后刷新显示器列表。')
  }, 8_000)
}

function gathered(current: RTCPeerConnection): Promise<void> {
  if (current.iceGatheringState === 'complete') return Promise.resolve()
  return new Promise(resolve => {
    const timer = setTimeout(finish, 2_000)
    function finish() {
      clearTimeout(timer)
      current.removeEventListener('icegatheringstatechange', changed)
      if (cancelGathering === finish) cancelGathering = undefined
      resolve()
    }
    function changed() { if (current.iceGatheringState === 'complete') finish() }
    cancelGathering = finish
    current.addEventListener('icegatheringstatechange', changed)
  })
}

export async function playViewing() {
  const current = generation
  try {
    await video?.play()
    if (current === generation) screen.needsPlay = false
  } catch {
    if (current === generation) {
      screen.needsPlay = true
      clearTimeout(timeout)
      timeout = setTimeout(() => { if (current === generation) fail('播放未能开始。准备好后请轻点“观看”重试。') }, 30_000)
    }
  }
}

export async function startViewing() {
  if (!canView() || !selectedDisplay() || !video || !screenSupported()) return
  if (settings.displayQuality === 'original' && (!connection.features.displayOriginal || !picture)) {
    fail('请更新 Mac 上的 CmdPalm 以使用高清文字，或选择其他观看画质。')
    return
  }
  closeStream()
  releaseAll()
  const current = generation
  const id = ++request
  streamId = id
  screen.status = 'connecting'
  screen.message = ''
  screen.original = settings.displayQuality === 'original'
  try {
    // Empty iceServers keeps negotiation entirely on the user's network.
    const rtc = new RTCPeerConnection({ iceServers: [], bundlePolicy: 'max-bundle' })
    peer = rtc
    if (screen.original) {
      const data = rtc.createDataChannel('cmdpalm.original', { ordered: true })
      channel = data
      data.binaryType = 'arraybuffer'
      data.onclose = () => { if (current === generation) fail('高清文字连接已结束。请重新开始观看。') }
      renderer = new ScreenImageRenderer(picture!, () => {
        clearTimeout(timeout)
        screen.status = 'live'
        screen.message = ''
      }, fail)
      data.onmessage = event => {
        if (current !== generation || !canView()) return
        try {
          if (!(event.data instanceof ArrayBuffer)) throw new Error('不支持的画面格式')
          const frame = images.push(event.data)
          if (frame) renderer?.receive(frame)
        } catch { fail('高清画面无法安全接收。请尝试「更清晰的文字」或重新连接。') }
      }
    } else {
      const transceiver = rtc.addTransceiver('video', { direction: 'recvonly' })
      const capabilities = typeof RTCRtpReceiver !== 'undefined' ? RTCRtpReceiver.getCapabilities?.('video') : undefined
      const codecs = capabilities?.codecs.filter(codec => ['video/h264', 'video/rtx'].includes(codec.mimeType.toLowerCase()))
      if (codecs?.some(codec => codec.mimeType.toLowerCase() === 'video/h264') && typeof transceiver.setCodecPreferences === 'function') transceiver.setCodecPreferences(codecs)
      rtc.ontrack = event => {
        if (current !== generation || !canView() || !video) { event.track.stop(); return }
        const receiver = event.receiver as (RTCRtpReceiver & { playoutDelayHint?: number; jitterBufferTarget?: number | null }) | undefined
        if (receiver) {
          try {
            if ('playoutDelayHint' in receiver) receiver.playoutDelayHint = 0
            if ('jitterBufferTarget' in receiver) receiver.jitterBufferTarget = 0
          } catch {
            // Ignore browsers that expose read-only or stricter jitter-buffer hints.
          }
        }
        video.srcObject = event.streams[0] ?? new MediaStream([event.track])
        video.onplaying = () => {
          if (current !== generation || !canView()) return
          clearTimeout(timeout)
          screen.status = 'live'
          screen.message = ''
          screen.needsPlay = false
        }
        void playViewing()
      }
    }
    rtc.onconnectionstatechange = () => {
      if (current !== generation) return
      clearTimeout(disconnected)
      if (rtc.connectionState === 'failed' || rtc.connectionState === 'closed') {
        fail('视频连接已结束。请检查你的 Wi-Fi 或 VPN，然后重新开始观看。')
      } else if (rtc.connectionState === 'disconnected') {
        screen.message = '视频连接中断…'
        disconnected = setTimeout(() => {
          if (current === generation) fail('视频连接已断开。网络恢复后请重新开始观看。')
        }, 5_000)
      } else if (rtc.connectionState === 'connected') screen.message = ''
    }
    timeout = setTimeout(() => {
      if (current === generation) fail('视频未能开始。请检查 Mac 上的屏幕录制权限，并确认你的网络允许直接视频连接。')
    }, 17_000)
    await rtc.setLocalDescription(await rtc.createOffer())
    await gathered(rtc)
    if (current !== generation || !canView()) return
    const sdp = rtc.localDescription?.sdp
    if (!sdp || !send({ t: 'displayStart', id, displayId: settings.displayId, quality: settings.displayQuality, sdp, ...(screen.original ? { patches: true } : {}) })) {
      fail('Mac 未连接。')
      return
    }
    send({ t: 'displayAlive', id })
    heartbeat = setInterval(() => {
      if (current !== generation || !canView()) { stopViewing(); return }
      send({ t: 'displayAlive', id })
    }, 1_000)
  } catch {
    if (current === generation) fail('浏览器无法启动实时画面。请刷新显示器列表后重试。')
  }
}

export function focusDisplay() {
  if (streamId !== null && screen.status === 'live' && connection.features.permission) send({ t: 'displayFocus', id: streamId })
}

export function activateScreen(element: HTMLVideoElement, image?: HTMLCanvasElement) {
  video = element
  picture = image ?? null
  if (screen.active) return
  screen.active = true
  refreshDisplays()
}

export function deactivateScreen() {
  screen.active = false
  listId = null
  clearTimeout(listTimeout)
  cancelAccessRequest()
  stopViewing()
  releaseAll()
  video = null
  picture = null
}

onMessage(message => {
  if (message.t === 'displays') {
    if (!visible() || message.id !== listId) return
    clearTimeout(listTimeout)
    listId = null
    // A refresh during a view only updates the choices. It never replaces
    // them with a failed list or changes what the live view is showing.
    const viewing = streamId !== null
    if (viewing && !message.displays.length) return
    screen.displays = message.displays
    // A feature update can finish this refresh before the approval fallback
    // timer fires. Never replace a usable list or interrupt its new viewer.
    if (message.displays.length) clearTimeout(approvalRefresh)
    screen.canRequest = message.canRequest === true && connection.features.displayRequests === true
    if (viewing) return
    screen.message = message.message ?? ''
    if (!settings.displayId && message.displays.length) settings.displayId = (message.displays.find(display => display.main) ?? message.displays[0]!).id
    if (settings.displayId && message.displays.length && !selectedDisplay()) screen.message = '所选显示器不可用。请在上方选择其他显示器。'
    screen.status = message.displays.length ? 'ready' : 'error'
  } else if (message.t === 'displayAccess') {
    if (!message.allowed) stopViewing('Mac 上已移除屏幕镜像权限。')
    if (canView() && accessId === null && streamId === null) refreshDisplays()
  } else if (message.t === 'displayRequest' && message.id === accessId) {
    screen.accessState = message.state
    screen.accessMessage = message.message ?? ''
    if (message.state !== 'pending') {
      accessId = null
      clearTimeout(accessTimeout)
      if (message.state === 'allowed' && canView()) {
        screen.canRequest = false
        clearTimeout(approvalRefresh)
        approvalRefresh = setTimeout(() => { if (canView() && !screen.displays.length) refreshDisplays() }, 350)
      }
    }
  } else if (message.t === 'displayState' && message.id === streamId) {
    if (message.state === 'answer' && message.sdp && peer) {
      const current = generation
      void peer.setRemoteDescription({ type: 'answer', sdp: message.sdp }).catch(() => {
        if (current === generation) fail('浏览器无法接受视频连接。请重试。')
      })
    } else if (message.state === 'error' || message.state === 'stopped') {
      stopViewing(message.message ?? '屏幕镜像已停止。', false)
    }
  }
})

watch([() => connection.status, () => connection.paused, () => connection.features.display], ([status, paused]) => {
  if (status !== 'connected' || paused) {
    cancelAccessRequest()
    listId = null
    clearTimeout(listTimeout)
    stopViewing(paused ? '屏幕镜像已在 Mac 上暂停。' : '请重新连接到 Mac，然后重新开始观看。')
    screen.displays = []
    screen.canRequest = false
  } else if (visible() && accessId === null) refreshDisplays()
}, { flush: 'sync' })

document.addEventListener('visibilitychange', () => {
  if (!visible()) {
    cancelAccessRequest()
    listId = null
    clearTimeout(listTimeout)
    stopViewing('准备好后请重新开始观看。')
  } else if (canView()) refreshDisplays()
})
addEventListener('pagehide', () => { cancelAccessRequest(); listId = null; clearTimeout(listTimeout); stopViewing() })
