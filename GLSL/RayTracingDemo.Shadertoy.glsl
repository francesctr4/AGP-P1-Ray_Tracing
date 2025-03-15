// --------------------------------- //
// ----------- CONSTANTS ----------- //
// --------------------------------- //

const float c_HALF_PI = 1.5707;
const float c_PI = 3.14159;
const float c_TAU = 6.2832;
const float c_PLANE_Y = -0.5;

const vec3 c_LIGHT_POS = vec3(2.0, 1.5, 2.0);
const vec3 c_LIGHT_COLOR = vec3(1.0);

// --------------------------------- //
// ----------- STRUCTURES ---------- //
// --------------------------------- //

struct Hit
{
    vec3 Point;
    vec3 Normal;
    float HitDistance;
    int HitID;
};

struct Sphere
{
    vec3 mOrigin;
    float mRadius;
    vec3 mColor;
    int mTextureID;
};

#define MAX_SPHERES 3
Sphere spheres[MAX_SPHERES];

// --------------------------------- //
// -------- GLOBAL VARIABLES ------- //
// --------------------------------- //

vec3 LightDirNorm = normalize(c_LIGHT_POS);
vec3 FresnelPass;

// --------------------------------- //
// ---------- LIGHTING ------------- //
// --------------------------------- //

vec3 ComputeLighting(vec3 normal, vec3 viewDir, vec3 lightDir, vec3 albedo, vec3 lightColor)
{
    // Ambient
    vec3 ambient = 0.1 * lightColor;
    
    // Diffuse
    float diff = max(dot(normal, lightDir), 0.0);
    vec3 diffuse = diff * lightColor;
    
    // Specular
    vec3 halfwayDir = normalize(lightDir + viewDir);
    float spec = pow(max(dot(normal, halfwayDir), 0.0), 60.0);
    vec3 specular = spec * lightColor;
    
    return (ambient + diffuse + specular) * albedo;
}

vec3 Fresnel(vec3 aDirection, vec3 aNormal)
{
    vec3 minValue = vec3(0.04);
    return minValue + (1.0 - minValue) * pow(1.0 - dot(aNormal, -aDirection), 5.0);
}

// --------------------------------- //
// ------------ SPHERES ------------ //
// --------------------------------- //

bool HitsSphere(vec3 aOrigin, vec3 aDirection, vec3 aSphereOrigin, float aRadius, out Hit aHit, int sphereID) 
{
    vec3 co = aSphereOrigin - aOrigin;
    float t1 = dot(co, aDirection);
    vec3 k = aOrigin + t1 * aDirection;
    vec3 ck = k - aSphereOrigin;
    float l1 = length(ck);
    
    if (l1 > aRadius) return false;

    float l2 = sqrt(aRadius * aRadius - l1 * l1);
    float t = t1 - l2;
    vec3 p = aOrigin + t * aDirection;

    if (p.y < -0.5) return false;

    aHit.Normal = normalize(p - aSphereOrigin);
    aHit.Point = p;
    aHit.HitDistance = length(p - aOrigin);
    aHit.HitID = sphereID;
    
    return t > 0.01;
}

bool HitsAnySphere(vec3 aCameraOrigin, vec3 aUVDirection, out Hit aOutHit, int aIgnoreID) 
{
    bool returnValue = false;
    float lastHitDepth = -1.0;
    
    for (int i = 0; i < MAX_SPHERES; ++i) 
    {
        Hit rayHitSphere;
        if (i != aIgnoreID && HitsSphere(aCameraOrigin, aUVDirection, spheres[i].mOrigin, 0.5, rayHitSphere, i)) 
        {
            if (lastHitDepth < 0.0 || rayHitSphere.HitDistance < lastHitDepth) 
            {
                aOutHit = rayHitSphere;
                returnValue = true;
                lastHitDepth = rayHitSphere.HitDistance;
            }
        }
    }
    return returnValue;
}

vec4 SampleTexture(int textureID, vec2 uv)
{
    if (textureID == 0) return texture(iChannel0, uv);
    if (textureID == 1) return texture(iChannel1, uv);
    if (textureID == 2) return texture(iChannel2, uv);
    
    return vec4(1.0);
}

vec2 MapSphereNormalToUV(vec3 normal)
{
    float theta = atan(normal.z, normal.x);
    float phi = acos(normal.y);
    
    return vec2((theta + c_PI) / c_TAU, phi / c_PI);
}

vec3 GetSphereColor(Hit rayHitSphere)
{
    int sphereID = rayHitSphere.HitID;
    
    if (sphereID < 0 || sphereID >= MAX_SPHERES) return vec3(1.0);
    
    vec2 sphereUV = MapSphereNormalToUV(rayHitSphere.Normal);
    vec4 textureColor = SampleTexture(spheres[sphereID].mTextureID, sphereUV);
    
    return textureColor.rgb * spheres[sphereID].mColor;
}

bool IsInShadow(vec3 hitPoint, vec3 lightDirection)
{
    Hit shadowHit;
    return HitsAnySphere(hitPoint, lightDirection, shadowHit, -1);
}

vec3 RenderAlbedo(vec3 aRayOrigin, vec3 aRayDirection, vec3 aPreColor)
{
    vec3 dir = normalize(aRayDirection);
    vec3 returnColor = aPreColor;
    float lastHitDistance = -1.0;

    for (int i = 0; i < MAX_SPHERES; ++i)
    {
        Hit rayHitSphere;
        if (HitsSphere(aRayOrigin, dir, spheres[i].mOrigin, spheres[i].mRadius, rayHitSphere, i))
        {
            if (lastHitDistance < 0.0 || rayHitSphere.HitDistance < lastHitDistance)
            {
                if (IsInShadow(rayHitSphere.Point, LightDirNorm))
                    returnColor = vec3(0.0);
                else 
                {
                    vec3 normal = normalize(rayHitSphere.Point - spheres[i].mOrigin);
                    vec3 viewDir = normalize(aRayOrigin - rayHitSphere.Point);
                    vec2 sphereUV = MapSphereNormalToUV(normal);
                    vec4 textureColor = SampleTexture(spheres[i].mTextureID, sphereUV);
                    vec3 albedo = mix(spheres[i].mColor, textureColor.rgb + spheres[i].mColor, textureColor.a);
                    
                    returnColor = ComputeLighting(normal, viewDir, LightDirNorm, albedo, c_LIGHT_COLOR);
                }
                
                lastHitDistance = rayHitSphere.HitDistance;
            }
        }
    }
    
    return returnColor;
}

// --------------------------------- //
// ------------- PLANE ------------- //
// --------------------------------- //

vec3 CheckerColor(vec2 uv, float multiplier)
{
    float pattern = mod(floor(uv.x * multiplier) + mod(floor(uv.y * multiplier), 2.0), 2.0);
    return vec3(1.8) * pattern;
}

bool HitsPlane(vec3 aOrigin, vec3 aDirection, float aPlaneY, out Hit aHit) 
{
    float t = (aPlaneY - aOrigin.y) / aDirection.y;
    if (t <= 0.01) return false;

    aHit.Point = aOrigin + t * aDirection;
    aHit.Normal = vec3(0.0, 1.0, 0.0);
    aHit.HitDistance = length(aHit.Point - aOrigin);
    aHit.HitID = -1;
    
    return true;
}

vec3 RenderPlane(vec3 aCameraOrigin, vec3 aUVDirection, vec3 aResultColor)
{
    Hit rayHitPlane;
    vec3 dir = normalize(aUVDirection);
    
    if (HitsPlane(aCameraOrigin, dir, c_PLANE_Y, rayHitPlane))
    {
        Hit sphereHit;
        if (HitsAnySphere(aCameraOrigin, dir, sphereHit, -1) && sphereHit.HitDistance < rayHitPlane.HitDistance)
            return aResultColor;

        if (IsInShadow(rayHitPlane.Point, LightDirNorm))
            aResultColor = vec3(0.0);
        else 
        {
            vec3 albedo = CheckerColor(rayHitPlane.Point.xz, 2.0);
            vec3 viewDir = normalize(aCameraOrigin - rayHitPlane.Point);
            aResultColor = ComputeLighting(rayHitPlane.Normal, viewDir, LightDirNorm, albedo, c_LIGHT_COLOR * 0.5);
            
            vec3 reflectDir = reflect(dir, rayHitPlane.Normal);
            Hit reflectHit;
            if (HitsAnySphere(rayHitPlane.Point + reflectDir * 0.001, reflectDir, reflectHit, -1))
            {
                vec3 reflectedColor = GetSphereColor(reflectHit);
                float fadeFactor = 1.0 - smoothstep(0.0, 0.5, reflectHit.Point.y - c_PLANE_Y);
                
                aResultColor = mix(aResultColor, reflectedColor, 0.5 * fadeFactor);
            }
        }
    }
    
    return aResultColor;
}

// --------------------------------- //
// -------------- SKY -------------- //
// --------------------------------- //

float hash(vec2 p)
{
    return fract(1e4 * sin(17.0 * p.x + p.y * 0.1) * (0.1 + abs(sin(p.y * 13.0 + p.x))));
}

float GeneratePerlinNoise(vec2 uv, vec2 divisions)
{
    vec2 downLeft = floor(uv * divisions);
    vec2 fracUV = fract(uv * divisions);
    fracUV = smoothstep(0.2, 0.8, fracUV);
    
    float c00 = hash(downLeft);
    float c10 = hash(downLeft + vec2(1.0, 0.0));
    float c01 = hash(downLeft + vec2(0.0, 1.0));
    float c11 = hash(downLeft + vec2(1.0, 1.0));
    
    return mix(mix(c00, c10, fracUV.x), mix(c01, c11, fracUV.x), fracUV.y);
}

vec3 GetSkyColor(float gradientY)
{
    return mix(vec3(0.901, 0.968, 1.0), vec3(0.623, 0.729, 0.996), gradientY);
}

vec3 GenerateClouds(vec2 uv, vec3 rayDirection)
{
    float finalNoise = 0.0;
    float weightSum = 0.0;
    float amplitude = 1.0;
    float frequency = 0.5;

    for (int i = 0; i < 6; ++i)
    {
        finalNoise += GeneratePerlinNoise(uv * frequency, vec2(2.0)) * amplitude;
        weightSum += amplitude;
        amplitude *= 0.75;
        frequency *= 2.0;
    }

    finalNoise = pow(finalNoise / weightSum, 0.4);
    
    return mix(vec3(0.7, 0.7, 1.0), vec3(1.0), finalNoise * 1.2);
}

vec3 RenderSky(vec3 aCameraOrigin, vec3 aRayDirection, vec3 aPreColor)
{
    Hit rayHitSky;
    vec2 uv;
    
    if (HitsPlane(aCameraOrigin, aRayDirection, 10.0, rayHitSky))
        uv = rayHitSky.Point.xz;

    float horizonFactor = clamp(aRayDirection.y * 0.5 + 0.5, 0.0, 1.0);
    
    vec3 skyColor = mix(vec3(0.1, 0.2, 0.6), vec3(0.5, 0.7, 1.0), horizonFactor);
    vec3 sunGlow = c_LIGHT_COLOR * pow(clamp(dot(aRayDirection, LightDirNorm), 0.0, 1.0), 8.0);
    vec3 finalSkyColor = skyColor * 0.8 + sunGlow;

    return mix(finalSkyColor, GenerateClouds(uv, aRayDirection), 0.8);
}

// --------------------------------- //
// ---------- REFLECTIONS ---------- //
// --------------------------------- //

float FresnelEffect(vec3 viewDir, vec3 normal)
{
    return pow(1.0 - max(dot(viewDir, normal), 0.0), 5.0);
}

bool HitsAnything(vec3 origin, vec3 direction, out Hit hit, int ignoreID)
{
    bool ret = false;
    float tempDepth = -1.0;

    if (HitsPlane(origin, direction, c_PLANE_Y, hit))
    {
        tempDepth = hit.HitDistance;
        ret = true;
    }

    Hit sphereHit;
    if (HitsAnySphere(origin, direction, sphereHit, ignoreID) && (tempDepth < 0.0 || sphereHit.HitDistance < tempDepth))
    {
        hit = sphereHit;
        ret = true;
    }
    
    return ret;
}

vec3 RenderReflection(vec3 aRayOrigin, vec3 aRayDirection)
{
    Hit firstHit;
    vec3 rayDirection = normalize(aRayDirection);
    if (!HitsAnything(aRayOrigin, rayDirection, firstHit, -1))
        return vec3(0.0);

    FresnelPass = Fresnel(rayDirection, firstHit.Normal);
    vec3 reflectDir = reflect(rayDirection, firstHit.Normal);
    vec3 newOrigin = firstHit.Point + reflectDir * 0.001;

    Hit secondHit;
    vec3 reflectionColor = vec3(0.0);
    if (HitsAnything(newOrigin, reflectDir, secondHit, -1))
    {
        if (secondHit.HitID == -1) // Plane hit
        {
            vec3 albedo = CheckerColor(secondHit.Point.xz, 2.0);
            vec3 viewDir = normalize(newOrigin - secondHit.Point);
            reflectionColor = ComputeLighting(secondHit.Normal, viewDir, LightDirNorm, albedo, c_LIGHT_COLOR * 0.5);
        }
        else // Sphere hit
        {
            reflectionColor = GetSphereColor(secondHit);
        }
    }
    else // Sky or no hit
    {
        reflectionColor = GetSkyColor(reflectDir.y);
    }

    return reflectionColor;
}

// --------------------------------- //
// ---------- CAMERA LOGIC --------- //
// --------------------------------- //

vec2 NormalizeUV(vec2 fragCoord, vec2 resolution)
{
    vec2 uv = fragCoord / resolution;
    uv = uv * 2.0 - 1.0;
    uv.x *= resolution.x / resolution.y;
    return uv;
}

vec3 CameraRayDirection(vec2 uv, vec3 target, float fov, float radius, out vec3 camPos)
{
    vec2 mouse = iMouse.xy / iResolution.xy;
    float yaw = mouse.x * c_TAU;
    float pitch = clamp(mouse.y * c_PI - c_HALF_PI, -c_HALF_PI, c_HALF_PI);

    camPos = target + vec3(radius * cos(pitch) * cos(yaw), radius * sin(pitch), radius * cos(pitch) * sin(yaw));
    camPos.y = max(camPos.y, c_PLANE_Y + 0.2);

    vec3 forward = normalize(target - camPos);
    vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), forward));
    vec3 up = cross(forward, right);
    
    float fovScale = tan(radians(fov) * 0.5);

    return normalize(uv.x * right * fovScale + uv.y * up * fovScale + forward);
}

// --------------------------------- //
// --------- SCENE RENDERING ------- //
// --------------------------------- //

vec3 ApplyDistanceFog(vec3 camPos, vec3 rayDirection, vec3 finalColor, float maxHeight, float fogStart, float fogEnd)
{
    Hit hit;
    float hitDistance = 100.0;
    
    if (HitsAnything(camPos, rayDirection, hit, -1))
        hitDistance = hit.HitDistance;

    float fogFactor = smoothstep(fogStart, fogEnd, hitDistance) * (1.0 - clamp(rayDirection.y * 2.0, 0.0, 1.0));
    
    return mix(finalColor, mix(vec3(1.0), c_LIGHT_COLOR, 0.5), fogFactor);
}

vec3 RenderScene(vec3 camPos, vec3 rayDirection)
{
    vec3 AlbedoPass = RenderSky(camPos, rayDirection, vec3(0.0));
    AlbedoPass = RenderPlane(camPos, rayDirection, AlbedoPass);
    AlbedoPass = RenderAlbedo(camPos, rayDirection, AlbedoPass);
    
    vec3 ReflectionPass = RenderReflection(camPos, rayDirection);
    
    vec3 finalColor = mix(AlbedoPass, ReflectionPass, FresnelPass * 1.2);
    
    finalColor = ApplyDistanceFog(camPos, rayDirection, finalColor, 1.0, -10.0, 100.0);
    
    return finalColor;
}

vec3 RenderSceneAA(vec3 camPos, vec3 worldRayDirection)
{
    vec3 finalColor = vec3(0.0);
    vec2 AAoffset = vec2(dFdx(worldRayDirection.x), dFdx(worldRayDirection.y));

    for (int x = -1; x <= 1; ++x)
    for (int y = -1; y <= 1; ++y)
    {
        vec3 dir = normalize(worldRayDirection + vec3(AAoffset.x * float(x), AAoffset.y * float(y), 0.0));
        finalColor += RenderScene(camPos, dir);
    }
    
    return finalColor / 9.0;
}

// --------------------------------- //
// ---------- MAIN SHADER ---------- //
// --------------------------------- //

void UpdateSpherePositions()
{
    spheres[0] = Sphere(vec3(0.6, sin(iTime) * 0.3, -2.0), 0.5, vec3(1.0, 0.0, 0.0), 0); // Red sphere
    spheres[1] = Sphere(vec3(0.5, 0.0, -3.0), 0.5, vec3(0.0, 1.0, 0.0), 1); // Green sphere
    spheres[2] = Sphere(vec3(-0.1, cos(iTime) * 0.3, -4.0), 0.5, vec3(0.0, 0.0, 1.0), 2); // Blue sphere
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{  
    UpdateSpherePositions();
    
    vec2 uv = NormalizeUV(fragCoord, iResolution.xy);
    
    // Camera management [uv, target, fov, radius, camPos]
    vec3 camPos = vec3(0.0f);
    vec3 worldRayDirection = CameraRayDirection(uv, spheres[1].mOrigin, 60.0f, 4.0f, camPos);
    
    // Render Scene Applying Anti-Aliasing
    vec3 finalColor = RenderSceneAA(camPos, worldRayDirection);
    
    fragColor = vec4(finalColor, 1.0f);
}