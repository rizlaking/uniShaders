// Tessellation domain shader
// After tessellation the domain shader processes the all the vertices
// S:\git\uniShaders\Shaders\E03_SpecularLighting\shaders\light_vs.hlsl(11,33-35): error X3530: invalid register specification, expected 'b' binding when cb used
cbuffer MatrixBuffer : register(b0)
{
    matrix worldMatrix;
    matrix viewMatrix;
    matrix projectionMatrix;
};

cbuffer TessellationWarpBuffer : register(b2)
{
	int powers;
	float repeats;
	float severity;
	float lerpAmount;
	float3 baseColour;
	bool targetSin;

}

struct ConstantOutputType
{
    float edges[3] : SV_TessFactor;
    float inside : SV_InsideTessFactor;
};

struct InputType
{
    float3 position : POSITION;
    float4 colour : COLOR;
	float3 viewDirection : TEXCOORD1;
};

struct OutputType
{
    float4 position : SV_POSITION;
    float4 colour : COLOR;
	float3 viewDirection : TEXCOORD1;
	float3 normal : NORMAL;
};

[domain("tri")]
OutputType main(ConstantOutputType input, float3 uvwCoord : SV_DomainLocation, const OutputPatch<InputType, 4> patch)
{
	float3 vertexPosition, normals;
	float3 sinVertexPosition, sinNormal;
	float3 cosVertexPosition, cosNormal;
    OutputType output;
 
    // Determine the position of the new vertex.
	// Invert the y and Z components of uvwCoord as these coords are generated in UV space and therefore y is positive downward.
	// Alternatively you can set the output topology of the hull shader to cw instead of ccw (or vice versa).
	vertexPosition = uvwCoord.x * patch[0].position + uvwCoord.y * patch[1].position + uvwCoord.z * patch[2].position;
    
	float4 sinColourModifier = float4(baseColour.x, baseColour.y, baseColour.z, 1.0f);
	float4 cosColourModifier = sinColourModifier;
	float4 colourModifier = sinColourModifier;
	float3 radialVector = vertexPosition;
	sinVertexPosition = vertexPosition;
	cosVertexPosition = vertexPosition;

	float vxr = vertexPosition.x * repeats;
	float vyr = vertexPosition.y * repeats;
	float vzr = vertexPosition.z * repeats;


	// Calculate sin wave surface modifier
	float sinWarp = 1.0f;
	float sinvx = sin(vxr);
	float sinvy = sin(vyr);
	float sinvz = sin(vzr);
	float sinvxyz = sinvx * sinvy * sinvz;

	for (int i = 0; i < powers; i++)
	{
		sinWarp *= sinvxyz;
	}

	float sinSev = sinWarp * severity;

	sinVertexPosition.x += radialVector.x * sinSev;
	sinVertexPosition.y += radialVector.y * sinSev;
	sinVertexPosition.z += radialVector.z * sinSev;

	// normal = -1 / ( s (sin(r x) sin(r y) sin(r z))^p + p r s x cot(r x) (sin(r x) sin(r y) sin(r z))^p + 1)
	
	// Calculate normals for sin configuration
	sinNormal.x = -1 / ((sinSev + 1) + (powers * sinSev * vxr * (1 / tan(vxr))));
	sinNormal.y = -1 / ((sinSev + 1) + (powers * sinSev * vyr * (1 / tan(vyr))));
	sinNormal.z = -1 / ((sinSev + 1) + (powers * sinSev * vzr * (1 / tan(vzr))));

	// Get unit normal
	sinNormal = normalize(sinNormal);

	sinColourModifier.x *= sinWarp;
	sinColourModifier.y *= sinWarp;
	sinColourModifier.z *= sinWarp;

	// Calculate cos wave surface modifier
	float cosWarp = 1.0f;
	float cosvx = cos(vxr);
	float cosvy = cos(vyr);
	float cosvz = cos(vzr);
	float cosvxyz = cosvx * cosvy * cosvz;

	for (int j = 0; j < powers; j++)
	{
		cosWarp *= cosvxyz;
	}

	float cosSev = cosWarp * severity;

	cosVertexPosition.x += radialVector.x * cosSev;
	cosVertexPosition.y += radialVector.y * cosSev;
	cosVertexPosition.z += radialVector.z * cosSev;

	// normal = -1 /( s (cos(r x) cos(r y) cos(r z))^p - p r s x tan(r x) (cos(r x) cos(r y) cos(r z))^p + 1)

	cosNormal.x = -1 / ((cosSev + 1) - (powers * cosSev * vxr * (tan(vxr))));
	cosNormal.y = -1 / ((cosSev + 1) - (powers * cosSev * vyr * (tan(vyr))));
	cosNormal.z = -1 / ((cosSev + 1) - (powers * cosSev * vzr * (tan(vzr))));

	cosNormal = normalize(cosNormal);

	cosColourModifier.x *= cosWarp;
	cosColourModifier.y *= cosWarp;
	cosColourModifier.z *= cosWarp;
	
	// Lerp between cos function and sin function
	if (targetSin)
	{
		vertexPosition.x = lerp(cosVertexPosition.x, sinVertexPosition.x, lerpAmount);
		vertexPosition.y = lerp(cosVertexPosition.y, sinVertexPosition.y, lerpAmount);
		vertexPosition.z = lerp(cosVertexPosition.z, sinVertexPosition.z, lerpAmount);
		 
		normals.x = lerp(cosNormal.x, sinNormal.x, lerpAmount);
		normals.y = lerp(cosNormal.y, sinNormal.y, lerpAmount);
		normals.z = lerp(cosNormal.z, sinNormal.z, lerpAmount);

		colourModifier.x = lerp(cosColourModifier.x, sinColourModifier.x, lerpAmount);
		colourModifier.y = lerp(cosColourModifier.y, sinColourModifier.y, lerpAmount);
		colourModifier.z = lerp(cosColourModifier.z, sinColourModifier.z, lerpAmount);
	}
	else
	{
		vertexPosition.x = lerp(sinVertexPosition.x, cosVertexPosition.x, 1 - lerpAmount);
		vertexPosition.y = lerp(sinVertexPosition.y, cosVertexPosition.y, 1 - lerpAmount);
		vertexPosition.z = lerp(sinVertexPosition.z, cosVertexPosition.z, 1 - lerpAmount);

		normals.x = lerp(sinNormal.x, cosNormal.x, 1 - lerpAmount);
		normals.y = lerp(sinNormal.y, cosNormal.y, 1 - lerpAmount);
		normals.z = lerp(sinNormal.z, cosNormal.z, 1 - lerpAmount);

		colourModifier.x = lerp(sinColourModifier.x, cosColourModifier.x, 1 - lerpAmount);
		colourModifier.y = lerp(sinColourModifier.y, cosColourModifier.y, 1 - lerpAmount);
		colourModifier.z = lerp(sinColourModifier.z, cosColourModifier.z, 1 - lerpAmount);
	}

	colourModifier *= 2;

	//colourModifier = normalize(colourModifier);
	colourModifier.x = clamp(colourModifier.x, 0.0f, 1.0f);
	colourModifier.y = clamp(colourModifier.y, 0.0f, 1.0f);
	colourModifier.z = clamp(colourModifier.z, 0.0f, 1.0f);
	colourModifier.a = 1.0f;

    // Calculate the position of the new vertex against the world, view, and projection matrices.
    output.position = mul(float4(vertexPosition, 1.0f), worldMatrix);
    output.position = mul(output.position, viewMatrix);
    output.position = mul(output.position, projectionMatrix);

	// Making the changes here uses the position in screen space

    // Send the input color into the pixel shader.
    output.colour = colourModifier;

	output.normal = normals;

    return output;
}
