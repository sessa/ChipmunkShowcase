/* Copyright (c) 2012 Scott Lembcke and Howling Moon Software
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#define CP_ALLOW_PRIVATE_ACCESS 1

#import "ShowcaseDemo.h"
#import "util.h"

#define FLUID_DENSITY 0.00014
#define FLUID_DRAG 3.0

@interface BuoyancyDemo : ShowcaseDemo @end
@implementation BuoyancyDemo

-(NSString *)name
{
	return @"Buoyancy";
}

-(NSTimeInterval)preferredTimeStep
{
	return 1.0/180.0;
}

-(void)setup
{
	self.space.gravity = cpv(0, -500);
	
	cpShapeFilter filter = cpShapeFilterNew(CP_NO_GROUP, NOT_GRABABLE_MASK, NOT_GRABABLE_MASK);
	[self.space addBounds:self.demoBounds thickness:100.0 elasticity:1.0 friction:1.0 filter:filter collisionType:nil];
	
	id waterID = @"water";
	id floatID = @"float";
	
	ChipmunkShape *sensor = [self.space add:[ChipmunkPolyShape boxWithBody:self.staticBody bb:cpBBNew(-1000, -1000, 1000, 0) radius:0.0]];
	sensor.sensor = TRUE;
	sensor.collisionType = waterID;

	{
		cpFloat width = 200.0f;
		cpFloat height = 50.0f;
		cpFloat mass = 0.8*FLUID_DENSITY*width*height;
		cpFloat moment = cpMomentForBox(mass, width, height);
		
		ChipmunkBody *body = [self.space add:[ChipmunkBody bodyWithMass:mass andMoment:moment]];
		body.position = cpv(-200, 200);
		
		ChipmunkShape *shape = [self.space add:[ChipmunkPolyShape boxWithBody:body width:width height:height radius:0.0]];
		shape.friction = 0.8;
		shape.collisionType = floatID;
	}
	
	{
		cpFloat width = 150.0f;
		cpFloat height = 150.0f;
		cpFloat mass = 0.1*FLUID_DENSITY*width*height;
		cpFloat moment = cpMomentForBox(mass, width, height);
		
		ChipmunkBody *body = [self.space add:[ChipmunkBody bodyWithMass:mass andMoment:moment]];
		body.position = cpv(0, 200);
		
		ChipmunkShape *shape = [self.space add:[ChipmunkPolyShape boxWithBody:body width:width height:height radius:0.0]];
		shape.friction = 0.8;
		shape.collisionType = floatID;
	}
	
	{
		cpFloat width = 100.0f;
		cpFloat height = 150.0f;
		cpFloat mass = 1.05*FLUID_DENSITY*width*height;
		cpFloat moment = cpMomentForBox(mass, width, height);
		
		ChipmunkBody *body = [self.space add:[ChipmunkBody bodyWithMass:mass andMoment:moment]];
		body.position = cpv(200, 200);
		
		ChipmunkShape *shape = [self.space add:[ChipmunkPolyShape boxWithBody:body width:width height:height radius:0.0]];
		shape.friction = 0.8;
		shape.collisionType = floatID;
	}
	
	// It's possible to mix C and Obj-C Chipmunk code.
	// In this case, a C callback is simpler.
	cpCollisionHandler *handler = cpSpaceAddCollisionHandler(self.space.space, waterID, floatID);
	handler->preSolveFunc = (cpCollisionPreSolveFunc)WaterPreSolve;
}

-(void)render:(PolyRenderer *)renderer showContacts:(BOOL)showContacts
{
	[super render:renderer showContacts:showContacts];
	
	[renderer drawSegmentFrom:cpv(-1000, 0) to:cpv(1000, 0) radius:1.0 color:RGBAColor(1, 1, 1, 1)];
}

// This function comes from the regular C Chipmunk demo.
// There is little reason other than lower performance to rewrite in Obj-C.
static cpBool
WaterPreSolve(cpArbiter *arb, cpSpace *space, void *ptr)
{
	CP_ARBITER_GET_SHAPES(arb, water, poly);
	cpBody *body = cpShapeGetBody(poly);
	
	// Get the top of the water sensor bounding box to use as the water level.
	cpFloat level = cpShapeGetBB(water).t;
	
	// Clip the polygon against the water level
	int count = cpPolyShapeGetCount(poly);
	int clippedCount = 0;
	cpVect clipped[count + 1];

	for(int i=0, j=count-1; i<count; j=i, i++){
		cpVect a = cpBodyLocalToWorld(body, cpPolyShapeGetVert(poly, j));
		cpVect b = cpBodyLocalToWorld(body, cpPolyShapeGetVert(poly, i));
		
		if(a.y < level){
			clipped[clippedCount] = a;
			clippedCount++;
		}
		
		cpFloat a_level = a.y - level;
		cpFloat b_level = b.y - level;
		
		if(a_level*b_level < 0.0f){
			cpFloat t = cpfabs(a_level)/(cpfabs(a_level) + cpfabs(b_level));
			
			clipped[clippedCount] = cpvlerp(a, b, t);
			clippedCount++;
		}
	}
	
	// Calculate buoyancy from the clipped polygon area
	cpFloat clippedArea = cpAreaForPoly(clippedCount, clipped, 0.0);
	cpFloat displacedMass = clippedArea*FLUID_DENSITY;
	cpVect centroid = cpCentroidForPoly(clippedCount, clipped);
	cpVect r = cpvsub(centroid, cpBodyGetPosition(body));
	
	cpFloat dt = cpSpaceGetCurrentTimeStep(space);
	cpVect g = cpSpaceGetGravity(space);
	
	// Apply the buoyancy force as an impulse.
	apply_impulse(body, cpvmult(g, -displacedMass*dt), r);
	
	// Apply linear damping for the fluid drag.
	cpVect v_centroid = cpvadd(body->v, cpvmult(cpvperp(r), body->w));
	cpFloat k = k_scalar_body(body, r, cpvnormalize(v_centroid));
	cpFloat damping = clippedArea*FLUID_DRAG*FLUID_DENSITY;
	cpFloat v_coef = cpfexp(-damping*dt*k); // linear drag
//	cpFloat v_coef = 1.0/(1.0 + damping*dt*cpvlength(v_centroid)*k); // quadratic drag
	apply_impulse(body, cpvmult(cpvsub(cpvmult(v_centroid, v_coef), v_centroid), 1.0/k), r);
	
	// Apply angular damping for the fluid drag.
	cpFloat w_damping = cpMomentForPoly(FLUID_DRAG*FLUID_DENSITY*clippedArea, clippedCount, clipped, cpvneg(body->p), 0.0);
	body->w *= cpfexp(-w_damping*dt*body->i_inv);
	
	return TRUE;
}

@end
