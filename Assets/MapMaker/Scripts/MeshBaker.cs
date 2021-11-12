using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UdonSharp;


public class MeshBaker : UdonSharpBehaviour
{


    /** Stratum **/

    /* Need to store :
     * Mesh index    (256)
     * Texture index (256)
     * Orientation    (4)
     * reserved | 4 | 8 | 8
     */

    private int[] map;
    private Texture2D texture;
    int length;
    int width;
    int mask;
    Mesh[] library;
    MeshFilter rendererFilter;
    CombineInstance[] stratumBaker;

    /* TODO :
     * Forget about the loading process for now.
     * Just focus on making the map
     * - 2DTextureArray shader with triplanar mapping
     *   that sample the texture index from the red
     *   color.
     * - Show and let the user select meshes
     *   available for the current stratum.
     *   // Show in a grid for the moment
     * - Show and let the user select textures
     *   available for the current stratum.
     *   // Same, show everything in a grid at the moment
     * - Let the user select a stratum :
     *    - Ensure that menus are refreshed when changing
     * - Show a texture that's filled with tiles representing
     *   the 3D tiles. // Could reuse the mesh ?
     */

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
        //wallsMeshFilter.sharedMesh = NewRandomMap(walls_map, walls, 7, 3);
        stopwatch.Stop();
        Debug.Log("Elapsed time : " + (stopwatch.ElapsedMilliseconds + "ms"));
    }

    private Mesh currentMesh;
    private Mesh[] currentLibrary;

    private int currentTextureIndex;
    private int currentMeshIndex;

    private ushort[] currentMap;
    private MeshFilter currentFilter;

    void RefreshMap()
    {
        Mesh newMesh = new Mesh();
        newMesh.CombineMeshes(toCombine);
        currentFilter.sharedMesh = newMesh;
    }

    
    Matrix4x4 zeroTranslation;

    Mesh CopyMesh(Mesh meshToCopy)
    {
        CombineInstance[] copier = new CombineInstance[1];
        CombineInstance ci = copier[0];
        ci.mesh = meshToCopy;
        ci.transform = zeroTranslation;
        copier[0] = ci;
        Mesh newMesh = new Mesh();
        newMesh.CombineMeshes(copier);

        return newMesh;

    }

    void SetupMeshForTexture(Mesh mesh, int textureIndex)
    {
        Color32[] colors = new Color32[mesh.vertices.Length];
        int colorsCount = colors.Length;

        for (int i = 0; i < colorsCount; i++)
        {
            Color32 color = colors[i];
            color.r = (byte) textureIndex;
            colors[i] = color;
        }

        mesh.colors32 = colors;
    }

    void PrepareMesh(int meshIndex, int textureIndex)
    {
        Mesh newSelection = CopyMesh(currentLibrary[meshIndex]);

        SetupMeshForTexture(newSelection, textureIndex);

        //newSelection.UploadMeshData(false);
        currentMesh = newSelection;
    }

    void RegenerateSelection()
    {
        PrepareMesh(currentMeshIndex, currentTextureIndex);
    }

    public void SelectMesh(int meshIndex)
    {
        currentMeshIndex = Mathf.Min(meshIndex, currentLibrary.Length-1);
        RegenerateSelection();
    }

    public void SelectTexture(int textureIndex)
    {
        currentTextureIndex = Mathf.Max(textureIndex, 0);
        RegenerateSelection();
    }

    int lastPosition = -1;
    public void SetMapTile(int x, int y)
    {
        x = Mathf.Clamp(x, 0, map_width - 1);
        y = Mathf.Clamp(y, 0, map_length - 1);
        int linear_tile_position = y * map_length + x;
        if (lastPosition == linear_tile_position) return;
        lastPosition = linear_tile_position;
        // FIXME : That's invalid ! You need to provide the mesh AND
        // texture index, on the bitmap
        // BUG
        currentMap[y * map_length + x] = (ushort) currentMeshIndex;
        CombineInstance ci = toCombine[linear_tile_position];
        ci.mesh = currentMesh;
        toCombine[linear_tile_position] = ci;

        RefreshMap();
    }

    void Start()
    {

        zeroTranslation = Matrix4x4.Translate(new Vector3(0,0,0));

        if (grounds.Length < 1) grounds = new Mesh[1];
        if (walls.Length < 1) walls = new Mesh[1];

        grounds[0] = new Mesh();
        walls[0] = new Mesh();
        stopwatch = new System.Diagnostics.Stopwatch();
     
        /* FIXME : This won't work with different walls and grounds sizes ! */
        map_size = map_length * map_width;
        toCombine = new CombineInstance[map_size];
        NewMess();
        /*SetMapTile(0, 0);
        SetMapTile(0, 1);
        SetMapTile(0, 2);*/

        currentLibrary = grounds;
        currentMap = ground_map;
        currentMeshIndex = 1;
        currentTextureIndex = 0;
        SelectMesh(1);
        SelectTexture(0);
        currentFilter = groundMeshFilter;

    }

}
