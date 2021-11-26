#if UNITY_EDITOR

using UnityEngine;
using UnityEditor;

namespace Myy
{
    public class TextureArrayGenerator : EditorWindow
    {
        SerializedObject serialO;
        SerializedProperty texturesSerialized;
        SerializedProperty textureNameSerialized;
        
        public string textureName;
        public Texture2D[] textures;
        public UnityEngine.Object saveDir;
        private string assetsDir;

        private void OnEnable()
        {
            assetsDir = Application.dataPath;
            serialO = new SerializedObject(this);
            texturesSerialized = serialO.FindProperty("textures");
            textureNameSerialized = serialO.FindProperty("textureName");
            
            saveDir = AssetDatabase.LoadAssetAtPath<UnityEngine.Object>("Assets");
        }

        [MenuItem("Voyage / Texture Array Generator")]
        public static void ShowWindow()
        {
            GetWindow(typeof(TextureArrayGenerator), false, "Texture Array Generator");
        }

        private void OnGUI()
        {
            bool everythingOK = true;
            serialO.Update();

            EditorGUILayout.PropertyField(textureNameSerialized);
            
            EditorGUILayout.PropertyField(texturesSerialized, true);
            serialO.ApplyModifiedProperties();

            if (!everythingOK) return;

            if (GUILayout.Button("Generate texture"))
            {
                Texture2D modelTexture = textures[0];
                int texturesCount = textures.Length;

                Texture2DArray array = new Texture2DArray(
                    modelTexture.width, modelTexture.height,
                    texturesCount, modelTexture.format, true);

                for (int t = 0; t < texturesCount; t++)
                {
                    Texture2D currentTexture = textures[t];
                    for (int mipMapLevel = 0; mipMapLevel < currentTexture.mipmapCount; mipMapLevel++)
                    {
                        Graphics.CopyTexture(textures[t], 0, mipMapLevel, array, t, mipMapLevel);
                    }
                }

                AssetDatabase.CreateAsset(array, $"Assets/{textureName}.asset");
            }

            if (GUILayout.Button("Generate texture (non-linear)"))
            {
                Texture2D modelTexture = textures[0];
                int texturesCount = textures.Length;

                Texture2DArray array = new Texture2DArray(
                    modelTexture.width, modelTexture.height,
                    texturesCount, modelTexture.format, false);

                for (int t = 0; t < texturesCount; t++)
                {
                    Texture2D currentTexture = textures[t];
                    for (int mipMapLevel = 0; mipMapLevel <1; mipMapLevel++)
                    {
                        Graphics.CopyTexture(textures[t], 0, mipMapLevel, array, t, mipMapLevel);
                    }
                }

                AssetDatabase.CreateAsset(array, $"Assets/{textureName}.asset");
            }
        }
    }
}
#endif