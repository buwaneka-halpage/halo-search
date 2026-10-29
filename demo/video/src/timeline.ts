import {Easing, interpolate} from 'remotion';
import log from './take-log.json';

export const FPS = 60;
export const WIDTH = 1920;
export const HEIGHT = 1080;

/** Seconds between the start of the recording and the director's clock (measured from the overlay frame). */
const RECORDING_OFFSET = 1.333;

type EventName =
	| 'start' | 'shortcut' | 'overlay' | 'circle' | 'circled' | 'panel' | 'ai-answer' | 'search-tab' | 'ai-tab'
	| 'typing' | 'follow-up' | 'follow-up-answer' | 'scribble' | 'scribbled' | 'text-answer' | 'closed' | 'end';

/** Time of a logged event in the source recording, in seconds. */
export const at = (event: EventName): number => {
	const found = log.events.find((e) => e.event === event);
	if (!found) throw new Error(`Missing event ${event}`);
	return found.t + RECORDING_OFFSET;
};

// The recording is played as one continuous take, sped up while Google is thinking.
type Segment = {from: number; to: number; rate: number};
const cuts: Array<[number, number]> = [
	[at('panel') + 0.2, 1],
	[at('ai-answer'), 2],
	[at('search-tab'), 1.25],
	[at('ai-tab'), 1.25],
	[at('follow-up') + 0.2, 1],
	[at('follow-up-answer'), 2],
	[at('scribble'), 1.25],
	[at('scribbled') + 0.6, 1],
	[at('text-answer'), 2],
	[at('closed'), 1.25],
	[at('closed') + 1.6, 1],
];
export const segments: Segment[] = cuts.map(([to, rate], index) => ({
	from: index === 0 ? at('start') + 0.5 : cuts[index - 1][0],
	to,
	rate,
}));

/** Output seconds (from the start of the footage) at which a source moment appears. */
export const out = (source: number): number => {
	let elapsed = 0;
	for (const segment of segments) {
		if (source <= segment.to) return elapsed + Math.max(0, source - segment.from) / segment.rate;
		elapsed += (segment.to - segment.from) / segment.rate;
	}
	return elapsed;
};

export const footageSeconds = out(Infinity);
export const segmentFrames = segments.map((segment) => ({
	...segment,
	start: Math.round(out(segment.from) * FPS),
	frames: Math.round(((segment.to - segment.from) / segment.rate) * FPS),
}));

/** Footage-relative output time of a logged event. */
export const when = (event: EventName, shift = 0) => out(at(event)) + shift;

// Scene layout, in seconds of the final video.
export const INTRO = 3.6;
export const FOOTAGE_START = 3.1;
export const FEATURES_START = FOOTAGE_START + footageSeconds + 0.1;
export const FEATURES = 4.8;
export const OUTRO_START = FEATURES_START + FEATURES - 0.3;
export const OUTRO = 4.6;
export const TOTAL = OUTRO_START + OUTRO;

// Camera: zoom `scale` around a focus point given as a fraction of the footage.
export type Camera = {scale: number; x: number; y: number};
const wide: Camera = {scale: 1, x: 0.5, y: 0.5};
const photo: Camera = {scale: 1.3, x: 0.24, y: 0.42};
const panel: Camera = {scale: 1.45, x: 0.86, y: 0.4};
const panelHeader: Camera = {scale: 1.9, x: 0.86, y: 0.16};
const term: Camera = {scale: 2.1, x: 0.57, y: 0.56};

const keyframes: Array<[number, Camera]> = [
	[0, wide],
	[when('circle', -0.6), wide],
	[when('circle', 0.1), photo],
	[when('circled', 0.3), photo],
	[when('panel', 0.5), panel],
	[when('ai-tab', -0.1), panel],
	[when('typing', 0.1), panelHeader],
	[when('follow-up', 0.3), panelHeader],
	[when('follow-up', 1.0), panel],
	[when('scribble', -0.9), panel],
	[when('scribble', -0.1), term],
	[when('scribbled', 0.5), term],
	[when('scribbled', 1.3), panel],
	[when('closed', -0.4), panel],
	[when('closed', 0.4), wide],
];

export const cameraAt = (seconds: number): Camera => {
	const index = keyframes.findIndex(([time]) => time > seconds);
	if (index <= 0) return index === 0 ? keyframes[0][1] : keyframes[keyframes.length - 1][1];
	const [t0, from] = keyframes[index - 1];
	const [t1, to] = keyframes[index];
	const p = interpolate(seconds, [t0, t1], [0, 1], {easing: Easing.inOut(Easing.cubic)});
	return {
		scale: from.scale + (to.scale - from.scale) * p,
		x: from.x + (to.x - from.x) * p,
		y: from.y + (to.y - from.y) * p,
	};
};

export const captions: Array<{start: number; end: number; step: number; text: string}> = [
	{start: when('shortcut', -0.9), end: when('circle', -0.15), step: 1, text: 'Press ⌃⇧Space anywhere'},
	{start: when('circle', -0.15), end: when('panel'), step: 2, text: "Circle anything you're curious about"},
	{start: when('panel'), end: when('search-tab'), step: 3, text: 'AI Mode explains what you circled'},
	{start: when('search-tab'), end: when('ai-tab'), step: 4, text: 'Google Lens finds visual matches'},
	{start: when('ai-tab'), end: when('scribble', -0.9), step: 5, text: 'Ask a follow-up — the image stays in context'},
	{start: when('scribble', -0.9), end: when('closed', -0.3), step: 6, text: 'Scribble over text to search it'},
	{start: when('closed', -0.3), end: footageSeconds, step: 7, text: 'Esc, and you’re back to work'},
];

export const rateAt = (seconds: number): number => {
	const segment = segmentFrames.find((s) => seconds * FPS < s.start + s.frames);
	return segment?.rate ?? 1;
};
