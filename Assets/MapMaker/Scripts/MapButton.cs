
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class MapButton : UdonSharpBehaviour
{
    public MeshBaker baker;
    public override void Interact()
    {
        baker.NewMess();
    }
}
