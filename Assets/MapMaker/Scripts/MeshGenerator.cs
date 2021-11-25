#if UNITY_EDITOR

using UnityEngine;
using UnityEditor;
using System.Collections.Generic;
using UnityEngine.Rendering;

namespace Myy
{
    public class MeshGenerator : EditorWindow
    {


        public string meshName;

        private SerializedObject serialO;
        private SerializedProperty meshNameSerialized;

        private CombineInstance[] copier;
        private void OnEnable()
        {
            copier = new CombineInstance[1];
            CombineInstance copy0 = new CombineInstance();
            copy0.mesh = GenerateSquare();
            copy0.transform = Matrix4x4.Translate(Vector3.zero);
            copier[0] = copy0;

            serialO = new SerializedObject(this);
            meshNameSerialized = serialO.FindProperty("meshName");
        }

        Mesh GenerateSquare()
        {
            
            Color32 white = new Color32(255,255,255,255);
            Vector3 normDir = -Vector3.forward;
            Vector3[] square =
            {
                new Vector3(-0.5f,0.5f,0), new Vector3(0.5f,0.5f,0),
                new Vector3(-0.5f,-0.5f,0), new Vector3(0.5f,-0.5f,0)
            };
            Vector3[] normals =
            {
                normDir, normDir, normDir, normDir
            };
            Color32[] colors =
            {
                white,white,white,white
            };
            Vector2[] uvs =
            {
                new Vector2(0,1), new Vector2(1,1),
                new Vector2(0,0), new Vector2(1,0)
            };
             int[] triangles =
            {
                0,1,2,
                3,2,1
            };
            Mesh mesh = new Mesh();
            mesh.vertices = square;
            mesh.normals  = normals;
            mesh.colors32 = colors;
            mesh.triangles = triangles;
            mesh.uv       = uvs;
            return mesh;
        }

        private Mesh GenerateSquareCopy(Color32 color)
        {
            Mesh mesh = new Mesh();
            CombineInstance copy0 = copier[0];
            mesh.CombineMeshes(copier);
            Color32[] colors = new Color32[] { color, color, color, color };
            mesh.colors32 = colors;
            return mesh;
        }





        [MenuItem("Voyage / Generate square")]
        public static void ShowWindow()
        {
            GetWindow(typeof(MeshGenerator), false, "Generate Square");
        }

        

        private void OnGUI()
        {
            serialO.Update();

            EditorGUILayout.PropertyField(meshNameSerialized);

            serialO.ApplyModifiedProperties();

            if (meshName == null || meshName == "") return;

            if (GUILayout.Button("Generate mesh"))
            {
                CombineInstance[] combiners = new CombineInstance[16];
                Vector3 v = Vector3.zero;
                for (int i = 0; i < 16; i++)
                {
                    v.x = i;
                    CombineInstance ci = combiners[i];
                    ci.mesh = GenerateSquareCopy(new Color32((byte)i, (byte)0, (byte)0, (byte)255));
                    ci.transform = Matrix4x4.Translate(v);
                    combiners[i] = ci;
                }
                Mesh newMesh = new Mesh();
                newMesh.CombineMeshes(combiners);
                AssetDatabase.CreateAsset(newMesh, "Assets/Assets/Materials/NormalTests/" + meshName + ".mesh");
            }
            
            
        }
    }
}
#endif