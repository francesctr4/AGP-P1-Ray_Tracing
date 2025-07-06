# Advanced Graphics Programming: P1 - Ray Tracing
![image](https://github.com/user-attachments/assets/67f5dee4-cc38-42c2-81fd-b3eb768c6bfd)
## Statement
### Implement a 3D Ray Tracer on Shadertoy.
The raycaster has several features amongst the following:
- Selection of the nearest intersected object
- Camera movement / mouse interaction
- Local illumination (ambient, diffuse, specular)
- Hard shadows
- Reflections
- Refraction
- Distance fog
- Cloudy sky
- Floor / sphere textures (checkerboard, marble, wood, etc)
- Antialiasing

## Features

This GLSL shader creates an interactive 3D scene featuring three textured spheres hovering above a reflective checkerboard plane, with dynamic lighting and atmospheric effects.

Here's a breakdown of its functionality:

### Core Elements

- Three spheres with textures (using iChannel0-2 inputs) that animate vertically using sine/cosine waves
- Checkerboard ground plane with reflective properties
- Dynamic directional lighting with shadows
- Sky with gradient colors, sun glow, and procedurally generated clouds
- Camera orbits around the central sphere controlled by mouse position

### Key Features

- **Ray Tracing**: Uses sphere/plane intersection tests for rendering
- **Lighting Model**: Phong shading (ambient + diffuse + specular)
- **Reflections**: Planar reflections with Fresnel effect
- **Texturing**: UV mapping on spheres using equirectangular projection
- **Effects**: Distance fog and anti-aliasing (3x3 supersampling)
- **Procedural Content**: Checkerboard pattern and cloud noise (Perlin-like)

### Technical Highlights

- Sphere positions update with iTime for animation
- Mouse-controlled orbital camera (yaw/pitch)
- Shadow calculations using secondary rays
- Fresnel reflections for realistic material blending
- Optimized ray traversal with early termination

### Input Dependencies

- _**iTime**_: For animation timing
- _**iMouse**_: For camera control
- _**iResolution**_: Screen dimensions
- _**iChannel0-2**_: Texture inputs for spheres
