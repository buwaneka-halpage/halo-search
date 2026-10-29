import React from 'react';
import {Composition} from 'remotion';
import {HaloDemo} from './HaloDemo';
import {FPS, HEIGHT, TOTAL, WIDTH} from './timeline';

export const Root: React.FC = () => (
	<Composition id="HaloDemo" component={HaloDemo} durationInFrames={Math.round(TOTAL * FPS)} fps={FPS} width={WIDTH} height={HEIGHT} />
);
