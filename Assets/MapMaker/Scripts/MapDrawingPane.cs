
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class MapDrawingPane : UdonSharpBehaviour
{

    public MeshBaker mapSystem;


    public void OnTriggerEnter(Collider other)
    {
        Debug.Log(other.transform);
    }

    public void OnCollisionEnter(Collision other)
    {
        Debug.Log(other.contacts[0].point);
    }

    void OnParticleCollision(GameObject other)
    {
        //Debug.Log("OnparticleCollider");
        Vector3 position = other.transform.position;
        Vector3 relative = position - gameObject.transform.position;
        int x = Mathf.FloorToInt(relative.x*10) + 4;
        int y = Mathf.FloorToInt(relative.y*10) + 4;
        
        //mapSystem.SetMapTile(x, y);
        //Debug.Log($"Transform : {relative} [{x}, {y}]");

    }


    void OnParticleTrigger()
    {
        Debug.Log("???");
    }

}
