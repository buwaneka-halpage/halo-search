import React from 'react';
import {AbsoluteFill, Sequence} from 'remotion';
import {Background, Features, Footage, Intro, Outro} from './Scenes';
import {FEATURES, FEATURES_START, FOOTAGE_START, footageSeconds, FPS, INTRO, OUTRO, OUTRO_START} from './timeline';

const f = (seconds: number) => Math.round(seconds * FPS);

export const HaloDemo: React.FC = () => (
	<AbsoluteFill>
		<Background />
		<Sequence durationInFrames={f(INTRO)}>
			<Intro />
		</Sequence>
		<Sequence from={f(FOOTAGE_START)} durationInFrames={f(footageSeconds + 0.2)}>
			<Footage />
		</Sequence>
		<Sequence from={f(FEATURES_START)} durationInFrames={f(FEATURES)}>
			<Features />
		</Sequence>
		<Sequence from={f(OUTRO_START)} durationInFrames={f(OUTRO)}>
			<Outro />
		</Sequence>
	</AbsoluteFill>
);
