using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UdonSharp;


public class MeshBaker : UdonSharpBehaviour
{

    public Mesh[] grounds;
    public Mesh[] walls; 

    private ushort[] ground_map = 
    {
        1,0,0,1,1,0,0,1,
        0,1,1,0,1,0,0,1,
        0,1,1,0,0,1,0,1,
        1,0,0,1,0,1,0,1,
        1,0,0,1,0,1,0,1,
        0,1,1,0,1,0,0,1,
        0,1,1,0,0,1,0,1,
        1,0,0,1,0,1,0,1
    };
    int map_length = 8;
    int map_width  = 8;
    int map_line_mask   = 7;

    int map_size = 0;

    private ushort[] walls_map =
    {
        1,0,0,1,1,0,0,1,
        0,1,1,0,1,0,0,1,
        0,1,1,0,0,1,0,1,
        1,0,0,1,0,1,0,1,
        1,0,0,1,0,1,0,1,
        1,0,0,1,0,1,0,1,
        1,0,0,1,0,1,0,1,
        1,0,0,1,0,1,0,1       
    };

    public MeshFilter groundMeshFilter;

    public MeshFilter wallsMeshFilter;

    private CombineInstance[] toCombine;

    Mesh MeshFromLibrary(Mesh[] library, int mesh_i)
    {
        return library[Mathf.Min(mesh_i, library.Length-1)];
    }

    // Start is called before the first frame update
    Mesh GenerateMapMesh(
        ushort[] map, Mesh[] library,
        int length_mask, int length_shift)
    {
        
        Mesh newMesh = new Mesh();
        int map_size_cached = map.Length;
        
        uint cmb_i = 0;
        for (int tile = 0; tile < map_size_cached; tile++)
        {
            Vector3 cur_pos = new Vector3(tile & length_mask, 0, (tile >> length_shift) & length_mask);    
            ushort tile_value = map[tile];
            toCombine[cmb_i].mesh = MeshFromLibrary(library, tile_value);
            toCombine[cmb_i].transform = Matrix4x4.Translate(cur_pos);
            cmb_i++;
        }

        newMesh.CombineMeshes(toCombine);
        return newMesh;
    }


    void GenerateMap(ushort[] map)
    {
        int map_size_cached = map.Length;
        for (uint tile = 0; tile < map_size_cached; tile++)
        {
            map[tile] = (ushort) Random.Range(0,6);
        }
    }

    System.Diagnostics.Stopwatch stopwatch;

    Mesh NewRandomMap(ushort[] map, Mesh[] library, int row_mask, int row_shift)
    {
        GenerateMap(map);
        return GenerateMapMesh(map, library, row_mask, row_shift);   
    }

    public void NewMess()
    {
        stopwatch.Reset();
        stopwatch.Start();
        groundMeshFilter.sharedMesh = NewRandomMap(ground_map, grounds, 7, 3);
        wallsMeshFilter.sharedMesh = NewRandomMap(walls_map, walls, 7, 3);
        stopwatch.Stop();
        Debug.Log("Elapsed time : " + (stopwatch.ElapsedMilliseconds + "ms"));
    }


    void Start()
    {
        if (grounds.Length < 1) grounds = new Mesh[1];
        if (walls.Length < 1) walls = new Mesh[1];

        grounds[0] = new Mesh();
        walls[0] = new Mesh();
        stopwatch = new System.Diagnostics.Stopwatch();
     
        /* FIXME : This won't work with different walls and grounds sizes ! */
        map_size = map_length * map_width;
        toCombine = new CombineInstance[map_size];

        NewMess();

    }

}
