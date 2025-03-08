class SlingshotGoatComponent extends GGMutatorComponent;

var GGGoat gMe;
var GGMutator myMut;

var name lastGoatState;
var float grabRadius;
var Actor lastGrabbedItem;
var bool wasGrabbing;
var bool tryLongGrab;
var bool usedLongGrab;

var bool tongueRetracted;
var float retractSpeed;

var bool isEPressed;
var bool isCharging;
var float maxChargeTime;
var ChargeHalo chrHalo;
var instanced GGRB_Handle grabber;
var AudioComponent mAC;
var float timeCharged;
var float invDetectRadius;

var float mThrowForce;
var Actor actToThrow;
var SoundCue throwSound;
var bool isATTGrabbed;

var int maxEggs;
var int eggsCount;
var YoshiEgg firstEgg;
var YoshiEgg lastEgg;
var instanced GGRB_Handle eggGrabber;

var GGCrosshairActor mCrosshairActor;

/**
 * See super.
 */
function AttachToPlayer( GGGoat goat, optional GGMutator owningMutator )
{
	super.AttachToPlayer(goat, owningMutator);

	if(mGoat != none)
	{
		gMe=goat;
		myMut=owningMutator;

		gMe.AttachComponent(mAC);

		if(mCrosshairActor == none)
		{
			mCrosshairActor = gMe.Spawn(class'GGCrosshairActor');
			mCrosshairActor.SetColor(MakeLinearColor( 1.f, 215.f/255.f, 0.1f, 1.0f ));
		}
	}
}

function DetachFromPlayer()
{
	mCrosshairActor.DestroyCrosshair();
	super.DetachFromPlayer();
}

function KeyState( name newKey, EKeyState keyState, PlayerController PCOwner )
{
	local GGPlayerInputGame localInput;

	if(PCOwner != gMe.Controller)
		return;

	localInput = GGPlayerInputGame( PCOwner.PlayerInput );

	if( keyState == KS_Down )
	{
		if( localInput.IsKeyIsPressed( "GBA_AbilityBite", string( newKey ) ) )
		{
			isEPressed=true;
			usedLongGrab=false;
			tryLongGrab=false;
			if(gMe.mGrabbedItem == none)
			{
				tryLongGrab=true;
			}

			if(isCharging)
			{
				EndCharge();
			}
		}

		if( localInput.IsKeyIsPressed( "GBA_Special", string( newKey ) ) )
		{
			if(!isEPressed && tongueRetracted)
			{
				ChargeShot();
			}
		}
	}
	else if( keyState == KS_Up )
	{
		if( localInput.IsKeyIsPressed( "GBA_AbilityBite", string( newKey ) ) )
		{
			isEPressed=false;
			if(tryLongGrab)
			{
				if(usedLongGrab)
				{
					tongueRetracted=false;
					SlowlyRetractTongue();
				}
				else
				{
					ResetTongue();
				}
			}
		}

		if( localInput.IsKeyIsPressed( "GBA_Special", string( newKey ) ) )
		{
			if(isCharging)
			{
				ThrowItem();
			}
		}
	}
}

function ExtendTongue()
{
	//myMut.WorldInfo.Game.Broadcast(myMut, "ExtendTongue");
	gMe.mGrabber.LinearDamping=1.f;
	gMe.mGrabber.LinearStiffness=1.f;
	gMe.mGrabber.AngularDamping=1.f;
	gMe.mGrabber.AngularStiffness=1.f;
}

function RetractTongue()
{
	//myMut.WorldInfo.Game.Broadcast(myMut, "RetractTongue");
	gMe.mGrabber.LinearDamping=1.f;
	gMe.mGrabber.LinearStiffness=1000000.f;
	gMe.mGrabber.AngularDamping=1.f;
	gMe.mGrabber.AngularStiffness=1000000.f;
	tongueRetracted=true;
}

function ResetTongue()
{
	//myMut.WorldInfo.Game.Broadcast(myMut, "ResetTongue");
	gMe.mGrabber.LinearDamping=gMe.mGrabber.default.LinearDamping;
	gMe.mGrabber.LinearStiffness=gMe.mGrabber.default.LinearStiffness;
	gMe.mGrabber.AngularDamping=gMe.mGrabber.default.AngularDamping;
	gMe.mGrabber.AngularStiffness=gMe.mGrabber.default.AngularStiffness;
	tongueRetracted=true;
}

function SlowlyRetractTongue()
{
	if(tongueRetracted)
		return;
	//myMut.WorldInfo.Game.Broadcast(myMut, "SlowlyRetractTongue");
	gMe.mGrabber.LinearDamping=1.f;
	gMe.mGrabber.LinearStiffness*=2.f;
	gMe.mGrabber.AngularDamping=1.f;
	gMe.mGrabber.AngularStiffness*=2.f;
	if(gMe.mGrabber.AngularStiffness >= 1000000.f)
	{
		RetractTongue();
	}
	else
	{
		gMe.SetTimer(retractSpeed, false, NameOf(SlowlyRetractTongue), self);
	}
	RegrabItem();
}

function LongGrab()
{
	local vector hitLocation, traceStart, traceEnd, hitNormal;
	local Actor hitActor;

	if(gMe.mIsRagdoll)
		return;

	//Get the first actor between the goat head and the crosshair
	traceStart=GetGrabLocation();
	traceEnd=traceStart + Normal(mCrosshairActor.Location-traceStart)*grabRadius;
	//gMe.DrawDebugLine (traceStart, traceEnd, 0, 0, 255, true);
	foreach gMe.TraceActors(class'Actor', hitActor, hitLocation, hitNormal, traceEnd, traceStart)
	{
		if(hitActor == gMe || hitActor.Owner == gMe)
			continue;

		break;
	}
	if(hitActor != none)
	{
		if(GrabItem(hitActor, hitLocation))
		{
			usedLongGrab=true;
			GGGameInfo( myMut.WorldInfo.Game ).OnUseAbility(gMe, gMe.mAbilities[ EAT_Bite ], hitActor);
		}
	}
	//myMut.WorldInfo.Game.Broadcast(myMut, "hitActor=" $ hitActor);
}

/**
 * Tries to grab an item.
 *
 * @param item - the item we wish to grab.
 *
 * @return - true if grabbed successfully; otherwise false.
 */
function bool GrabItem( Actor item, vector grabLocation )
{
	local name boneName;
	local PrimitiveComponent grabComponent;
	local vector dummyExtent, dummyOutPoint, closestPoint;
	local GJKResult closestPointResult;
	local GGPhysicalMaterialProperty physProp;
	local GGGrabbableActorInterface grabbableInterface;

	grabbableInterface = GGGrabbableActorInterface( item );

	if( grabbableInterface == none )
	{
		return false;
	}

	boneName = grabbableInterface.GetGrabInfo( grabLocation );

	if( grabbableInterface.CanBeGrabbed( gMe, boneName ) )
	{
		grabComponent = grabbableInterface.GetGrabbableComponent();
		physProp = grabbableInterface.GetPhysProp();

		grabbableInterface.OnGrabbed( gMe );
	}
	else
	{
		return false;
	}

	// Grab the item.
	gMe.mGrabber.GrabComponent( grabComponent, boneName, grabLocation, false );
	gMe.mActorsToIgnoreBlockingBy.AddItem( item );
	gMe.mGrabbedItem = item;

	// Cache location for the tongue.
	if( gMe.mGrabber.GrabbedBoneName == 'None' )
	{
		closestPointResult = gMe.mGrabber.GrabbedComponent.ClosestPointOnComponentToPoint( grabLocation, dummyExtent, dummyOutPoint, closestPoint );
		if( closestPointResult == GJK_NoIntersection )
		{
			gMe.mGrabbedLocalLocation = InverseTransformVector( gMe.mGrabber.GrabbedComponent.LocalToWorld, closestPoint );
		}
		else
		{
			gMe.mGrabbedLocalLocation = InverseTransformVector( gMe.mGrabber.GrabbedComponent.LocalToWorld, gMe.mGrabbedItem.Location );
		}
	}

	if( physProp != none && physProp.ShouldAlertNPCs() )
	{
		gMe.NotifyAIControlllersGrabbedItem();
	}

	return true;
}

//Update the grabber strength
function bool RegrabItem()
{
	local name boneName;
	local PrimitiveComponent grabComponent;
	local vector grabLocation;

	if(gMe.mGrabbedItem == none)
	{
		return false;
	}

	if( gMe.mGrabber.GrabbedBoneName != 'None' )
	{
		grabLocation = SkeletalMeshComponent( gMe.mGrabber.GrabbedComponent ).GetBoneLocation( gMe.mGrabber.GrabbedBoneName );
	}
	else
	{
		grabLocation = TransformVector( gMe.mGrabber.GrabbedComponent.LocalToWorld, gMe.mGrabbedLocalLocation );
	}
	boneName=gMe.mGrabber.GrabbedBoneName;
	grabComponent = GGGrabbableActorInterface( gMe.mGrabbedItem ).GetGrabbableComponent();

	// Regrab the item.
	gMe.mGrabber.GrabComponent( grabComponent, boneName, grabLocation, false );

	return true;
}

function ChargeShot()
{
	local vector throwLocation, actPos;
	local GGGrabbableActorInterface grabbableInterface;
	local name boneName;

	isATTGrabbed=false;
	if(gMe.IsTimerActive(NameOf(GrabActorToThrow), self))
	{
		gMe.ClearTimer(NameOf(GrabActorToThrow), self);
	}

	if(gMe.mGrabbedItem == none && !wasGrabbing)
	{
		throwLocation=GetThrowLocation();
		if(gMe.mInventory != none && gMe.mInventory.mInventorySlots.Length > 0)
		{
			gMe.mInventory.RemoveFromInventory(0);
			actToThrow=Actor(gMe.mInventory.mLastItemRemoved);
			if(GGPawn(actToThrow) != none)
			{
				GGPawn(actToThrow).mesh.SetRBLinearVelocity(vect(0, 0, 0));
			}
		}
		else if(eggsCount > 0)
		{
			actToThrow=GetYoshiEgg();
		}
		else
		{
			actToThrow = gMe.Spawn( class'SmallRock', gMe,, throwLocation,,, true);
			actToThrow.CollisionComponent.WakeRigidBody();
		}
	}

	if(gMe.mGrabbedItem != none)
	{
		//Reset tongue strength when charging
		if(usedLongGrab)
		{
			ResetTongue();
			RegrabItem();
		}
		if(YoshiEgg(gMe.mGrabbedItem) != none)
		{
			YoshiEgg(gMe.mGrabbedItem).TakeEgg();
		}
		actToThrow=gMe.mGrabbedItem;
		isATTGrabbed=true;
	}
	else if(actToThrow != none && !isATTGrabbed)
	{
		//Grab the actor to throw if not already grabbed
		gMe.SetTimer(0.1f, false, NameOf(GrabActorToThrow), self);
	}
	else
	{
		return;
	}
	//myMut.WorldInfo.Game.Broadcast(myMut, "actToThrow=" $ actToThrow);

	if(actToThrow != none)
	{
		if(YoshiEgg(actToThrow) != none)
		{
			YoshiEgg(actToThrow).isExplosive=false;
		}

		isCharging=true;
		gMe.SetTimer(maxChargeTime, false, NameOf(MaxCharge), self);
		grabbableInterface = GGGrabbableActorInterface( actToThrow );
		actPos=actToThrow.CollisionComponent.GetPosition();
		boneName = grabbableInterface.GetGrabInfo( actPos );
		grabber.GrabComponent( grabbableInterface.GetGrabbableComponent(), boneName, actPos, false );
		mAC.FadeIn( 0.5f, 1.0f );
		chrHalo.AttachHalo(actToThrow);
	}
}

//Fix combination with yoshi goat mutator
function GrabActorToThrow()
{
	if(!isCharging || isATTGrabbed || actToThrow == none)
	{
		return;
	}

	GrabItem(actToThrow, GGPawn(actToThrow)!=none?GGPawn(actToThrow).mesh.GetPosition():actToThrow.Location);
	isATTGrabbed=(gMe.mGrabbedItem == actToThrow);
	if(!isATTGrabbed)
	{
		gMe.SetTimer(0.1f, false, NameOf(GrabActorToThrow), self);
	}
}

function EndCharge()
{
	local SmallRock sr;

	isATTGrabbed=false;
	if(gMe.IsTimerActive(NameOf(MaxCharge), self))
	{
		gMe.ClearTimer(NameOf(MaxCharge), self);
	}
	timeCharged=0.f;
	mAC.Stop();
	gMe.DropGrabbedItem();
	grabber.ReleaseComponent();
	chrHalo.FadeHalo();
	isCharging=false;
	sr=SmallRock(actToThrow);
	if(sr != none)
	{
		sr.StartCountdown();
	}
	if(YoshiEgg(actToThrow) != none)
	{
		YoshiEgg(actToThrow).isExplosive=true;
		actToThrow.SetOwner(none);
	}
	actToThrow=none;
}

function MaxCharge()
{
	chrHalo.ActivateHalo();
}

function ThrowItem()
{
	local GGPawn gpawn;
	local PrimitiveComponent throwComp;
	local vector dir;
	local float chargeTime;
	local float chargeMultiplier;

	if(gMe.mIsRagdoll || actToThrow == none || !isCharging)
	{
		EndCharge();
		return;
	}

	//Multiplier between 1 (wait 0s) and 2 (wait 2s)
	chargeTime=gMe.GetTimerCount(NameOf(MaxCharge), self);
	if(chargeTime == -1)
	{
		chargeTime=maxChargeTime;
	}
	chargeMultiplier=(chargeTime/maxChargeTime)*gMe.mAttackMomentumMultiplier + 1.f;

	dir=Normal(mCrosshairActor.Location-GetThrowLocation());

	gpawn = GGPawn(actToThrow);

	throwComp=actToThrow.CollisionComponent;
	if(gpawn != none)
	{
		throwComp=gpawn.mesh;
	}
	throwComp.SetRBLinearVelocity(dir*mThrowForce*chargeMultiplier);

	gMe.PlaySound(throwSound);

	EndCharge();
}

function vector GetThrowLocation()
{
	local vector throwLocation;

	gMe.mesh.GetSocketWorldLocationAndRotation( 'Demonic', throwLocation );
	if(IsZero(throwLocation))
	{
		throwLocation=gMe.Location + (Normal(vector(gMe.Rotation)) * (gMe.GetCollisionRadius() + 30.f));
	}

	return throwLocation;
}

function vector GetEggLocation()
{
	local vector eggLocation;

	gMe.mesh.GetSocketWorldLocationAndRotation( 'ButtSocket', eggLocation );
	if(IsZero(eggLocation))
	{
		eggLocation=gMe.Location - (Normal(vector(gMe.Rotation)) * (gMe.GetCollisionRadius() + 30.f));
	}

	return eggLocation;
}

function vector GetGrabLocation()
{
	local vector grabLocation;

	gMe.mesh.GetSocketWorldLocationAndRotation( 'grabSocket', grabLocation );
	if(IsZero(grabLocation))
	{
		grabLocation=gMe.Location + vect(0, 0, 1) * gMe.GetCollisionHeight() + (Normal(vector(gMe.Rotation)) * gMe.GetCollisionRadius());
	}

	return grabLocation;
}



function TickMutatorComponent(float deltaTime)
{
	local name currGoatState;
	local vector throwLocation, eggLocation;
	local GGBombActor ggba;

	super.TickMutatorComponent(deltaTime);
	currGoatState=gMe.GetStateName();
	throwLocation=GetThrowLocation();
	eggLocation=GetEggLocation();
	UpdateCrosshair(throwLocation);

	if(chrHalo == none || chrHalo.bPendingDelete)
	{
		chrHalo = gMe.Spawn(class'ChargeHalo',,,,,, true);
	}

	grabber.SetLocation(throwLocation);
	eggGrabber.SetLocation(eggLocation);

	//Immediately after item dropped
	if(gMe.mGrabbedItem == none && lastGrabbedItem != none)
	{
		ResetTongue();
		//Yoshi easter egg
		foreach gMe.OverlappingActors(class'GGBombActor', ggba, 100.0f, eggLocation)
		{
			MakeYoshiEgg(ggba);
		}
	}

	//Immediately after the lick action
	if(currGoatState != 'AbilityBite' && lastGoatState == 'AbilityBite')
	{
		if(gMe.mGrabbedItem == none && tryLongGrab)
		{
			ExtendTongue();
			LongGrab();
		}
	}

	//Can't grab an attached egg
	if(YoshiEgg(gMe.mGrabbedItem) != none && YoshiEgg(gMe.mGrabbedItem).isAttached)
	{
		gMe.DropGrabbedItem();
	}

	if(isCharging)
	{
		//Stop charge if actor destroyed
		if(actToThrow == none || (isATTGrabbed && gMe.mGrabbedItem == none))
		{
			EndCharge();
		}
		else
		{
			//Manage charge sound pitch
			if(timeCharged < maxChargeTime)
			{
				timeCharged+=deltaTime;
				if(timeCharged > maxChargeTime)
					timeCharged = maxChargeTime;
			}

			mAC.PitchMultiplier = mAC.default.PitchMultiplier + timeCharged - 1.5f;
		}
	}

	lastGrabbedItem=gMe.mGrabbedItem;
	wasGrabbing=(lastGrabbedItem!=none);
	lastGoatState=currGoatState;
}

function UpdateCrosshair(vector aimLocation)
{
	local vector			StartTrace, EndTrace, AdjustedAim, camLocation;
	local rotator 			camRotation;
	local Array<ImpactInfo>	ImpactList;
	local ImpactInfo 		RealImpact;
	local float 			Radius;

	if(gMe != None)
	{
		StartTrace = aimLocation;

		GGPlayerControllerGame( gMe.Controller ).PlayerCamera.GetCameraViewPoint( camLocation, camRotation );
		camRotation.Pitch+=1800.f;
		AdjustedAim = vector(camRotation);

		Radius = mCrosshairActor.SkeletalMeshComponent.SkeletalMesh.Bounds.SphereRadius;
		EndTrace = StartTrace + AdjustedAim * (grabRadius - Radius);

		RealImpact = CalcWeaponFire(StartTrace, EndTrace, ImpactList);

		mCrosshairActor.UpdateCrosshair(RealImpact.hitLocation, -AdjustedAim);
	}
}

simulated function ImpactInfo CalcWeaponFire(vector StartTrace, vector EndTrace, optional out array<ImpactInfo> ImpactList)
{
	local vector			HitLocation, HitNormal;
	local Actor				HitActor;
	local TraceHitInfo		HitInfo;
	local ImpactInfo		CurrentImpact;

	HitActor = CustomTrace(HitLocation, HitNormal, EndTrace, StartTrace, HitInfo);

	if( HitActor == None )
	{
		HitLocation	= EndTrace;
	}

	CurrentImpact.HitActor		= HitActor;
	CurrentImpact.HitLocation	= HitLocation;
	CurrentImpact.HitNormal		= HitNormal;
	CurrentImpact.RayDir		= Normal(EndTrace-StartTrace);
	CurrentImpact.StartTrace	= StartTrace;
	CurrentImpact.HitInfo		= HitInfo;

	ImpactList[ImpactList.Length] = CurrentImpact;

	return CurrentImpact;
}

function Actor CustomTrace(out vector HitLocation, out vector HitNormal, vector EndTrace, vector StartTrace, out TraceHitInfo HitInfo)
{
	local Actor hitActor, retActor;

	foreach gMe.TraceActors(class'Actor', hitActor, HitLocation, HitNormal, EndTrace, StartTrace, ,HitInfo)
    {
		if(hitActor != gMe
		&& hitActor.Owner != gMe
		&& hitActor.Base != gMe
		&& hitActor != gMe.mGrabbedItem
		&& !hitActor.bHidden)
		{
			retActor=hitActor;
			break;
		}
    }

    return retActor;
}

function MakeYoshiEgg(GGBombActor oldBomb)
{
	local YoshiEgg newBomb;
	local vector spawnLoc;

	if(eggsCount >= maxEggs || oldBomb == none)
	{
		return;
	}

	oldBomb.ClearTimer('Explode');
	oldBomb.ShutDown();

	spawnLoc=GetEggLocation();
	newBomb=gMe.Spawn( class'YoshiEgg',gMe,, spawnLoc,,, true);
	newBomb.sgc=self;
	eggsCount++;
	//myMut.WorldInfo.Game.Broadcast(myMut, "MakeYoshiEg=>" $ eggsCount);


	if(firstEgg == none)
	{
		lastEgg=newBomb;
	}
	else
	{
		newBomb.AttachEgg(firstEgg);
		firstEgg.previousEgg=newBomb;
	}
	firstEgg=newBomb;
	AttachEgg(newBomb);
}

function YoshiEgg GetYoshiEgg()
{
	local YoshiEgg retEgg, prevEgg;

	if(eggsCount <= 0)
	{
		return none;
	}

	retEgg=lastEgg;
	prevEgg=lastEgg.previousEgg;
	if(prevEgg == none)
	{
		firstEgg=none;
		DetachEgg();
	}
	else
	{
		prevEgg.DetachEgg();
	}
	lastEgg=prevEgg;
	eggsCount--;
	//myMut.WorldInfo.Game.Broadcast(myMut, "GetYoshiEgg=>" $ eggsCount);

	return retEgg;
}

function AttachEgg(YoshiEgg newBomb)
{
	local vector actPos;
	local GGGrabbableActorInterface grabbableInterface;
	local name boneName;

	if(newBomb == none)
	{
		return;
	}

	grabbableInterface = GGGrabbableActorInterface( newBomb );
	actPos=newBomb.CollisionComponent.GetPosition();
	boneName = grabbableInterface.GetGrabInfo( actPos );
	eggGrabber.GrabComponent( grabbableInterface.GetGrabbableComponent(), boneName, actPos, false );
	firstEgg.isAttached=true;
}

function DetachEgg()
{
	eggGrabber.ReleaseComponent();
	lastEgg.isAttached=false;
}

defaultproperties
{
	Begin Object Class=AudioComponent Name=GrapplingHookAudioComponent
        bUseOwnerLocation=true
        SoundCue=SoundCue'Goat_Sounds.Cue.Effect_Goat_grappling_tongue_loop_cue'
    End Object
    mAC=GrapplingHookAudioComponent

	Begin Object class=GGRB_Handle name=ObjectGrabber
        LinearDamping=1.f
        LinearStiffness=1000000.f
        AngularDamping=1.f
        AngularStiffness=1000000.f
    End Object
    grabber=ObjectGrabber

	Begin Object class=GGRB_Handle name=EggGrabber1
        LinearDamping=20.0
        LinearStiffness=20.0
        AngularDamping=1.0
        AngularStiffness=1.0
    End Object
    eggGrabber=EggGrabber1

	throwSound=SoundCue'Goat_Sounds.Cue.HeadButt_Cue'

	mThrowForce=1000.f
	grabRadius=10000.f
	maxChargeTime=2.f
	retractSpeed=0.1f
	invDetectRadius=500.f

	maxEggs=6
}