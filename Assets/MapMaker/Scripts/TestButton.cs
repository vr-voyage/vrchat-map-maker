
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class TestButton : UdonSharpBehaviour
{

    public Pencil pencil;

    public override void Interact()
    {
        pencil.NextStratum();
    }
}
