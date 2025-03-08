class SmallRock extends GGKActor;

var bool triedToDestroy;
var bool init;

function string GetActorName()
{
	return "Small Rock";
}

function StartCountdown()
{
	//Destroy itself after 10 seconds
	SetTimer(10.f, false, NameOf(TryDestroy));
	SetOwner(none);
	init=true;
}

event Tick( float deltaTime )
{
    super.Tick( deltaTime );

	if(init && !triedToDestroy && !IsTimerActive(NameOf(TryDestroy)))
	{
		TryDestroy();
	}
}

function TryDestroy()
{
	if(!triedToDestroy && !bDeleteMe && !bPendingDelete)
	{
		triedToDestroy=true;
		if(!Destroy())
		{
			ShutDown();
		}
	}
}

DefaultProperties
{
	Begin Object name=StaticMeshComponent0
		StaticMesh=StaticMesh'Boulder.Mesh.Boulder_01'
		Scale=0.05f
	End Object

	bNoDelete=false
	bStatic=false
}