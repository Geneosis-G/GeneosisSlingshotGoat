class ChargeHalo extends Actor;

var ParticleSystem chargeHaloTemplate;
var ParticleSystemComponent chargeHalo;
var bool isAttached;
var Actor myBase;
var float fadeTime;

simulated event PostBeginPlay ()
{
	Super.PostBeginPlay();

	SetPhysics(PHYS_None);
	CollisionComponent=none;
	chargeHalo = WorldInfo.MyEmitterPool.SpawnEmitter( chargeHaloTemplate, Location, Rotation, self );
	chargeHalo.SetHidden(true);
}

function AttachHalo(Actor target)
{
	DetachHalo();
	myBase=target;
	SetLocation(target.Location);
	SetBase(myBase);
	isAttached=true;
}

function DetachHalo()
{
	if(!isAttached)
		return;

	if(IsTimerActive(NameOf(DetachHalo)))
	{
		ClearTimer(NameOf(DetachHalo));
	}
	SetBase(none);
	chargeHalo.SetHidden(true);
	isAttached=false;
}

function ActivateHalo()
{
	chargeHalo.SetHidden(false);
}

function FadeHalo()
{
	if(isAttached)
	{
		SetTimer(fadeTime, false, NameOf(DetachHalo));
	}
}

event Tick( float deltaTime )
{
    super.Tick( deltaTime );

	if(isAttached && (myBase == none || myBase.bPendingDelete))
	{
		DetachHalo();
	}
}

DefaultProperties
{
	chargeHaloTemplate=ParticleSystem'MMO_Effects.Effects.Effects_Glow_01'

	bNoDelete=false
	bStatic=false
	bIgnoreBaseRotation=true

	fadeTime=5.f
}