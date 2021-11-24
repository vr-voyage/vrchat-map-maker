# Requirements

* Unity 2019.4.31f1
* VRCSDK3 WORLD 2021.11.08.14.28
  * This is important, previous SDK won't allow
    `CombineInstance`.
* UdonSharp (latest version you can find)

# Copyrights

* Textures :
  * Some of them are generated with
  [MaterialMaker](https://materialmaker.org), based on
  the online assets shared on their website .
  * Others come from VRChat SDK (might replace them
    by Kenney's ones in the future).
* Skybox Shader is a modified version of Unity
  Skybox by Lyuma.

# TODO

* [ ] Triplanar shader with Texture2DArray.
  * [x] Sample the texture index from the vertex color
* [ ] User drawing interface
  * Marker & Tablet might just work.
    * [x] Add a marker & tablet models, with a trigger collider
      at the tip of the marker.
    * [ ] Pre generate colliders for each tile
    * [x] Pregenerate a mesh based on the user selection (mesh + style).
    * [x] For each tile touched by the marker, define the
      relative CombineInstance.mesh and regenerate the Mesh.
    * [x] Add a button to switch from the Ground to the Walls.
      * [ ] For the walls, only activate the colliders that are near
            a ground tile.
    * [ ] For desktop users, allow them to box or line
          select, by clicking on the beginning and then the end
          of the box, or line (for walls).

