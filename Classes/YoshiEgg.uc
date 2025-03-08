class YoshiEgg extends GGKactor
	implements( GGExplosiveActorInterface )
	placeable;

/** If the bomb is already exploding it should not explode again */
var bool mIsExploding;

/** The momentum caused at an explosion */
var float mExplosiveMomentum;

/** The damage caused at an explosion */
var int mDamage;

/** The radius the explosion will affect */
var float mDamageRadius;

/** The damage type for the explosion */
var class< GGDamageTypeExplosiveActor > mDamageType;

/** The sound for the explosion */
var SoundCue mExplosionSound;

/** The particle effect for the explosion */
var ParticleSystem mExplosionEffectTemplate;

/** Class of ExplosionLight */
var class< UDKExplosionLight > mExplosionLightClass;

/** Where this actor is when it explodes */
var vector mExplosionLoc;

var instanced GGRB_Handle grabber;
var YoshiEgg previousEgg;
var YoshiEgg nextEgg;
var bool isExplosive;
var SlingshotGoatComponent sgc;
var bool isDestroyed;
var bool isAttached;
var float previousDist;

simulated event PostBeginPlay()
{
	super.PostBeginPlay();

	SetPhysics( PHYS_RigidBody );
    StaticMeshComponent.InitRBPhys();
    StaticMeshComponent.StaticMesh.BodySetup.MassScale = 0.5;
    StaticMeshComponent.BodyInstance.UpdateMassProperties( StaticMeshComponent.StaticMesh.BodySetup );
	StaticMeshComponent.WakeRigidBody();
}

function Explode()
{
	if( mIsExploding )
	{
		return;
	}

	mIsExploding = true;

	mExplosionLoc = Location;

	// Notify kismet and the game about the explosion
	TriggerEventClass( class'GGSeqEvent_Explosion', self );
	GGGameInfo( WorldInfo.Game ).OnExplosion( self );

	HurtRadius( mDamage, mDamageRadius, mDamageType, mExplosiveMomentum, Location, , GGGoat( Owner ).Controller );

	SpawnExplosionEffects();

	Shutdown();
}

simulated function SpawnExplosionEffects()
{
	if( mExplosionSound != none )
	{
		PlaySound( mExplosionSound, true, true );
	}

	if( mExplosionEffectTemplate != none )
	{
		WorldInfo.MyEmitterPool.SpawnEmitter( mExplosionEffectTemplate, Location );
	}

	if( mExplosionLightClass != none && UDKEmitterPool( WorldInfo.MyEmitterPool ) != none )
	{
		UDKEmitterPool( WorldInfo.MyEmitterPool ).SpawnExplosionLight( mExplosionLightClass, Location );
	}
}

function float GetDamageRadius()
{
	return mDamageRadius;
}

function vector GetExplosionLocation()
{
	return mExplosionLoc;
}

function int GetDamage()
{
	return mDamage;
}

function float GetExplosiveMomentum()
{
	return mExplosiveMomentum;
}

function Actor GetInstigator()
{
	return none;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////

function AttachEgg(YoshiEgg newBomb)
{
	local vector actPos;
	local GGGrabbableActorInterface grabbableInterface;
	local name boneName;

	if(newBomb == none)
	{
		return;
	}

	nextEgg=newBomb;
	grabbableInterface = GGGrabbableActorInterface( newBomb );
	actPos=newBomb.CollisionComponent.GetPosition();
	boneName = grabbableInterface.GetGrabInfo( actPos );
	grabber.GrabComponent( grabbableInterface.GetGrabbableComponent(), boneName, actPos, false );
	nextEgg.isAttached=true;
}

function DetachEgg()
{
	grabber.ReleaseComponent();
	nextEgg.isAttached=false;
}

event Tick( float deltaTime )
{
	super.Tick( deltaTime );

	UpdateEggGrabberForce();
	grabber.SetLocation(CollisionComponent.GetPosition());
}

function UpdateEggGrabberForce()
{
	local float dist;
	local vector dir;

	if(!isAttached)
	{
		return;
	}

	if(previousEgg == none)
	{
		dir=sgc.eggGrabber.Location - CollisionComponent.GetPosition();
	}
	else
	{
		dir=previousEgg.CollisionComponent.GetPosition() - CollisionComponent.GetPosition();
	}
	dist=VSize(dir);
	dir=Normal(dir);

	if(dist > 500.f)
	{
		ApplyImpulse(dir, StaticMeshComponent.BodyInstance.GetBodyMass()*dist, -dir);
	}
}

function string GetActorName()
{
	return "Egg";
}

function TakeEgg()
{
	if(!isAttached)
	{
		return;
	}

	grabber.ReleaseComponent();
	if(previousEgg != none)
	{
		previousEgg.DetachEgg();
		previousEgg.AttachEgg(nextEgg);
		if(sgc.lastEgg == self)
		{
			sgc.lastEgg=previousEgg;
		}
	}
	else
	{
		sgc.DetachEgg();
		sgc.AttachEgg(nextEgg);
		sgc.firstEgg=nextEgg;
		if(sgc.firstEgg == none)
		{
			sgc.lastEgg=none;
		}
	}
	sgc.eggsCount--;
	//WorldInfo.Game.Broadcast(self, "TakeEgg=>" $ sgc.eggsCount);
}

simulated event ShutDown()
{
	super.ShutDown();

	TakeEgg();
}

simulated event Destroyed()
{
	super.Destroyed();

	TakeEgg();
}

function bool ShouldIgnoreActor(Actor act)
{
	//WorldInfo.Game.Broadcast(self, "shouldIgnoreActor=" $ act);
	return !isExplosive
		|| act == none
		|| Volume(act) != none
		|| GGApexDestructibleActor(act) != none
		|| act == self;
}

simulated event TakeDamage( int damage, Controller eventInstigator, vector hitLocation, vector momentum, class< DamageType > damageType, optional TraceHitInfo hitInfo, optional Actor damageCauser )
{
	super.TakeDamage(damage, eventInstigator, hitLocation, momentum, damageType, hitInfo, damageCauser);
	//WorldInfo.Game.Broadcast(self, "TakeDamage=" $ damageCauser);
	HitActor(damageCauser);
}

event Bump( Actor Other, PrimitiveComponent OtherComp, Vector HitNormal )
{
    super.Bump(Other, OtherComp, HitNormal);
	//WorldInfo.Game.Broadcast(self, "Bump=" $ other);
	HitActor(other);
}

event RigidBodyCollision(PrimitiveComponent HitComponent, PrimitiveComponent OtherComponent, const out CollisionImpactData RigidCollisionData, int ContactIndex)
{
	super.RigidBodyCollision(HitComponent, OtherComponent, RigidCollisionData, ContactIndex);
	//WorldInfo.Game.Broadcast(self, "RBCollision=" $ OtherComponent.Owner);
	HitActor(OtherComponent!=none?OtherComponent.Owner:none);
}

function HitActor(optional Actor target)
{
	if(ShouldIgnoreActor(target))
		return;

	Explode();
}

defaultproperties
{
	Begin Object class=GGRB_Handle name=ObjectGrabber
        LinearDamping=20.0
        LinearStiffness=20.0
        AngularDamping=1.0
        AngularStiffness=1.0
    End Object
    grabber=ObjectGrabber

	mExplosiveMomentum=50000.0f
	mDamage=100
	mDamageRadius=500.0f
	mDamageType=class'GGDamageTypeExplosiveActor'

	mExplosionSound=SoundCue'Goat_Sounds.Cue.Explosion_Car_Cue'
	mExplosionEffectTemplate=ParticleSystem'Goat_Effects.Effects.Projectile_Explosion_01'
	mExplosionLightClass=class'GGExplosionLight'

	bCollideWorld=true
	bNoEncroachCheck=false

	Begin Object name=StaticMeshComponent0
		StaticMesh=StaticMesh'Food.Mesh.WaterMelon_01'
		bNotifyRigidBodyCollision=true
		ScriptRigidBodyCollisionThreshold=10.0f //If too big, we won't get any notifications from collisions between kactors
		CollideActors=true
		BlockActors=true
		BlockZeroExtent=true
		BlockNonZeroExtent=true
		Scale=1.5f
	End Object

	bCollideActors=true
	bBlockActors=true
	bPawnCanBaseOn=false

	bStatic=false
	bNoDelete=false
}