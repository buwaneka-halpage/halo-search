import React from 'react';
import {AbsoluteFill, Img, interpolate, OffthreadVideo, Sequence, spring, staticFile, useCurrentFrame, useVideoConfig, Easing} from 'remotion';
import {cameraAt, captions, footageSeconds, FPS, rateAt, segmentFrames, when} from './timeline';

export const COLORS = {blue: '#4285F4', red: '#EA4335', yellow: '#FBBC05', green: '#34A853'};
export const FONT = '"SF Pro Display", system-ui, -apple-system, sans-serif';
const HALO = `conic-gradient(from 0deg, ${COLORS.blue}, ${COLORS.red}, ${COLORS.yellow}, ${COLORS.green}, ${COLORS.blue})`;

const seconds = (frame: number) => frame / FPS;
const fade = (frame: number, start: number, length = 0.4) =>
	interpolate(seconds(frame), [start, start + length], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});

// MARK: Background

/** Dark canvas with slow-moving glows in Google's colours. */
export const Background: React.FC = () => {
	const t = seconds(useCurrentFrame());
	const blobs = [
		{color: COLORS.blue, x: 22, y: 30, r: 760, phase: 0},
		{color: COLORS.red, x: 80, y: 22, r: 620, phase: 1.7},
		{color: COLORS.yellow, x: 72, y: 85, r: 640, phase: 3.1},
		{color: COLORS.green, x: 18, y: 82, r: 600, phase: 4.4},
	];
	return (
		<AbsoluteFill style={{background: '#07070d', overflow: 'hidden'}}>
			{blobs.map((b) => (
				<div
					key={b.color}
					style={{
						position: 'absolute',
						left: `calc(${b.x + Math.sin(t * 0.35 + b.phase) * 6}% - ${b.r / 2}px)`,
						top: `calc(${b.y + Math.cos(t * 0.3 + b.phase) * 6}% - ${b.r / 2}px)`,
						width: b.r,
						height: b.r,
						borderRadius: '50%',
						background: b.color,
						opacity: 0.2,
						filter: 'blur(140px)',
					}}
				/>
			))}
			<AbsoluteFill style={{background: 'radial-gradient(ellipse at center, transparent 40%, rgba(0,0,0,0.55) 100%)'}} />
		</AbsoluteFill>
	);
};

// MARK: Intro

const Halo: React.FC<{size: number; opacity: number; spin: number}> = ({size, opacity, spin}) => (
	<div
		style={{
			position: 'absolute',
			width: size,
			height: size,
			borderRadius: '50%',
			background: HALO,
			transform: `rotate(${spin}deg)`,
			opacity,
			WebkitMaskImage: 'radial-gradient(circle, transparent 58%, black 61%, black 66%, transparent 70%)',
			maskImage: 'radial-gradient(circle, transparent 58%, black 61%, black 66%, transparent 70%)',
			filter: 'blur(3px)',
		}}
	/>
);

export const Intro: React.FC = () => {
	const frame = useCurrentFrame();
	const {fps} = useVideoConfig();
	const t = seconds(frame);
	const pop = spring({frame: frame - 0.25 * fps, fps, config: {damping: 13, stiffness: 120}});
	const ring = spring({frame: frame - 0.1 * fps, fps, config: {damping: 20, stiffness: 60}});
	const exit = interpolate(t, [2.9, 3.6], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.in(Easing.cubic)});
	const title = fade(frame, 0.9, 0.5);
	const subtitle = fade(frame, 1.35, 0.5);

	return (
		<AbsoluteFill style={{alignItems: 'center', justifyContent: 'center', fontFamily: FONT, opacity: 1 - exit, transform: `scale(${1 - exit * 0.08})`}}>
			<div style={{position: 'relative', width: 420, height: 420, display: 'flex', alignItems: 'center', justifyContent: 'center', marginTop: -150}}>
				<Halo size={420 * (0.6 + ring * 0.4)} opacity={ring * 0.9} spin={t * 40} />
				<Halo size={520 * (0.6 + ring * 0.4)} opacity={ring * 0.25} spin={-t * 25} />
				<Img src={staticFile('icon.png')} style={{width: 230, height: 230, transform: `scale(${pop})`}} />
			</div>
			<div style={{color: 'white', fontSize: 96, fontWeight: 700, letterSpacing: -2, opacity: title, transform: `translateY(${(1 - title) * 24}px)`, marginTop: 10}}>
				Halo Search
			</div>
			<div style={{color: 'rgba(255,255,255,0.72)', fontSize: 36, fontWeight: 400, marginTop: 14, opacity: subtitle, transform: `translateY(${(1 - subtitle) * 18}px)`}}>
				Circle anything on your Mac. Ask Google about it.
			</div>
		</AbsoluteFill>
	);
};

// MARK: Footage

const CARD = {width: 1380, height: Math.round(1380 / (3300 / 2224))};
const CARD_TOP = 34;

const Keycaps: React.FC<{start: number}> = ({start}) => {
	const frame = useCurrentFrame();
	const {fps} = useVideoConfig();
	const t = seconds(frame) - start;
	if (t < -0.1 || t > 1.9) return null;
	const appear = spring({frame: frame - start * fps, fps, config: {damping: 14}});
	const leave = interpolate(t, [1.5, 1.9], [1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
	const press = t > 0.75 && t < 1.0 ? 0.92 : 1;
	return (
		<AbsoluteFill style={{alignItems: 'center', justifyContent: 'center', opacity: leave}}>
			<div style={{display: 'flex', gap: 22, transform: `scale(${appear * press})`}}>
				{['⌃', '⇧', 'Space'].map((key) => (
					<div
						key={key}
						style={{
							minWidth: 128,
							height: 128,
							padding: '0 34px',
							borderRadius: 26,
							display: 'flex',
							alignItems: 'center',
							justifyContent: 'center',
							fontFamily: FONT,
							fontSize: key === 'Space' ? 46 : 64,
							fontWeight: 500,
							color: '#1d1d22',
							background: 'linear-gradient(180deg, #ffffff, #e7e7ee)',
							boxShadow: press < 1 ? '0 3px 0 #b9b9c4, 0 10px 30px rgba(0,0,0,.35)' : '0 9px 0 #b9b9c4, 0 22px 50px rgba(0,0,0,.45)',
						}}
					>
						{key}
					</div>
				))}
			</div>
		</AbsoluteFill>
	);
};

const Caption: React.FC = () => {
	const frame = useCurrentFrame();
	const t = seconds(frame);
	const current = captions.find((c) => t >= c.start && t < c.end);
	if (!current) return null;
	const local = t - current.start;
	const inP = interpolate(local, [0, 0.35], [0, 1], {extrapolateRight: 'clamp', easing: Easing.out(Easing.cubic)});
	const outP = interpolate(t, [current.end - 0.25, current.end], [1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
	const progress = (t - current.start) / (current.end - current.start);
	return (
		<div style={{position: 'absolute', top: CARD_TOP + CARD.height + 22, left: 0, right: 0, display: 'flex', justifyContent: 'center'}}>
			<div
				style={{
					display: 'flex',
					alignItems: 'center',
					gap: 18,
					padding: '13px 30px 13px 14px',
					borderRadius: 999,
					background: 'rgba(255,255,255,0.09)',
					border: '1px solid rgba(255,255,255,0.14)',
					backdropFilter: 'blur(20px)',
					fontFamily: FONT,
					opacity: inP * outP,
					transform: `translateY(${(1 - inP) * 14}px)`,
					position: 'relative',
					overflow: 'hidden',
				}}
			>
				<div style={{width: 40, height: 40, borderRadius: 20, background: Object.values(COLORS)[(current.step - 1) % 4], color: 'white', fontSize: 21, fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center'}}>
					{current.step}
				</div>
				<div style={{color: 'white', fontSize: 30, fontWeight: 600, letterSpacing: -0.3}}>{current.text}</div>
				<div style={{position: 'absolute', left: 0, bottom: 0, height: 3, width: `${progress * 100}%`, background: HALO, opacity: 0.8}} />
			</div>
		</div>
	);
};

const SpeedBadge: React.FC = () => {
	const t = seconds(useCurrentFrame());
	const rate = rateAt(t);
	const visible = rate !== 1;
	return (
		<div
			style={{
				position: 'absolute',
				top: CARD_TOP + 18,
				left: (1920 - CARD.width) / 2 + 18,
				padding: '7px 14px',
				borderRadius: 10,
				background: 'rgba(10,10,16,0.72)',
				color: 'white',
				fontFamily: FONT,
				fontSize: 20,
				fontWeight: 600,
				opacity: visible ? 1 : 0,
				transition: 'none',
			}}
		>
			▶▶ {rate}×
		</div>
	);
};

export const Footage: React.FC = () => {
	const frame = useCurrentFrame();
	const {fps} = useVideoConfig();
	const t = seconds(frame);
	const enter = spring({frame, fps, config: {damping: 18, stiffness: 90}});
	const leave = interpolate(t, [footageSeconds - 0.5, footageSeconds + 0.1], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.in(Easing.cubic)});

	const camera = cameraAt(t);
	const {width: W, height: H} = CARD;
	const tx = Math.min(0, Math.max(W - camera.scale * W, W / 2 - camera.scale * camera.x * W));
	const ty = Math.min(0, Math.max(H - camera.scale * H, H / 2 - camera.scale * camera.y * H));

	return (
		<AbsoluteFill style={{opacity: 1 - leave}}>
			<div
				style={{
					position: 'absolute',
					left: (1920 - W) / 2,
					top: CARD_TOP,
					width: W,
					height: H,
					borderRadius: 22,
					overflow: 'hidden',
					boxShadow: '0 40px 120px rgba(0,0,0,0.6), 0 0 0 1px rgba(255,255,255,0.12)',
					transform: `translateY(${(1 - enter) * 260}px) scale(${0.9 + enter * 0.1 - leave * 0.06})`,
				}}
			>
				<div style={{position: 'absolute', width: W, height: H, transformOrigin: '0 0', transform: `translate(${tx}px, ${ty}px) scale(${camera.scale})`}}>
					{segmentFrames.map((segment) => (
						<Sequence key={segment.start} from={segment.start} durationInFrames={segment.frames} layout="none">
							<OffthreadVideo
								src={staticFile('footage.mp4')}
								trimBefore={Math.round(segment.from * fps)}
								playbackRate={segment.rate}
								muted
								style={{width: W, height: H, display: 'block'}}
							/>
						</Sequence>
					))}
				</div>
			</div>
			<SpeedBadge />
			<Caption />
			<Keycaps start={when('shortcut', -0.75)} />
		</AbsoluteFill>
	);
};

// MARK: Features

const features = [
	{color: COLORS.blue, title: 'AI Mode + Lens', text: 'Answers and visual matches, side by side.'},
	{color: COLORS.red, title: 'Reads any text', text: 'On-device OCR. Scribble over words to search.'},
	{color: COLORS.yellow, title: 'Native & light', text: 'Swift and AppKit, living in your menu bar.'},
	{color: COLORS.green, title: 'Private by default', text: 'Nothing leaves your Mac until you select.'},
];

export const Features: React.FC = () => {
	const frame = useCurrentFrame();
	const {fps, durationInFrames} = useVideoConfig();
	const leave = interpolate(frame, [durationInFrames - 0.4 * fps, durationInFrames], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
	const heading = fade(frame, 0.1, 0.5);
	return (
		<AbsoluteFill style={{alignItems: 'center', justifyContent: 'center', fontFamily: FONT, opacity: 1 - leave}}>
			<div style={{color: 'white', fontSize: 64, fontWeight: 700, letterSpacing: -1.2, marginBottom: 56, opacity: heading, transform: `translateY(${(1 - heading) * 20}px)`}}>
				Circle to search, made for the Mac
			</div>
			<div style={{display: 'grid', gridTemplateColumns: '660px 660px', gap: 28}}>
				{features.map((feature, index) => {
					const p = spring({frame: frame - (0.35 + index * 0.14) * fps, fps, config: {damping: 16}});
					return (
						<div
							key={feature.title}
							style={{
								padding: '30px 34px',
								borderRadius: 26,
								background: 'rgba(255,255,255,0.07)',
								border: '1px solid rgba(255,255,255,0.12)',
								opacity: p,
								transform: `translateY(${(1 - p) * 40}px) scale(${0.94 + p * 0.06})`,
								display: 'flex',
								gap: 24,
								alignItems: 'center',
							}}
						>
							<div style={{width: 58, height: 58, borderRadius: 29, flex: 'none', background: feature.color, boxShadow: `0 0 40px ${feature.color}88`}} />
							<div>
								<div style={{color: 'white', fontSize: 34, fontWeight: 650}}>{feature.title}</div>
								<div style={{color: 'rgba(255,255,255,0.68)', fontSize: 24, marginTop: 6, lineHeight: 1.35}}>{feature.text}</div>
							</div>
						</div>
					);
				})}
			</div>
		</AbsoluteFill>
	);
};

// MARK: Outro

export const Outro: React.FC = () => {
	const frame = useCurrentFrame();
	const {fps, durationInFrames} = useVideoConfig();
	const t = seconds(frame);
	const pop = spring({frame, fps, config: {damping: 14}});
	const text = fade(frame, 0.35, 0.5);
	const link = fade(frame, 0.8, 0.5);
	const out = interpolate(frame, [durationInFrames - 0.7 * fps, durationInFrames], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
	return (
		<AbsoluteFill style={{alignItems: 'center', justifyContent: 'center', fontFamily: FONT}}>
			<div style={{position: 'relative', width: 300, height: 300, display: 'flex', alignItems: 'center', justifyContent: 'center', marginTop: -60}}>
				<Halo size={300 * (0.7 + pop * 0.3)} opacity={pop * 0.85} spin={t * 40} />
				<Img src={staticFile('icon.png')} style={{width: 170, height: 170, transform: `scale(${pop})`}} />
			</div>
			<div style={{color: 'white', fontSize: 78, fontWeight: 700, letterSpacing: -1.6, opacity: text, marginTop: 8}}>Halo Search</div>
			<div style={{color: 'rgba(255,255,255,0.7)', fontSize: 30, marginTop: 10, opacity: text}}>Free and open source · macOS 14 and later</div>
			<div
				style={{
					marginTop: 40,
					padding: '16px 34px',
					borderRadius: 999,
					background: 'white',
					color: '#111',
					fontSize: 30,
					fontWeight: 600,
					opacity: link,
					transform: `translateY(${(1 - link) * 16}px)`,
				}}
			>
				github.com/buwaneka-halpage/halo-search
			</div>
			<AbsoluteFill style={{background: 'black', opacity: out}} />
		</AbsoluteFill>
	);
};
