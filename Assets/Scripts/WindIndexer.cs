using UnityEngine;

namespace Windy
{
    public class WindIndexer : MonoBehaviour
    {
        #region Constants

        private const string cWindIndexPropertyName = "_WindIndex";

        #endregion

        #region Fields

        [SerializeField] private SpriteRenderer _SpriteRenderer;

        private static readonly int sWindIndexPropertyID;

        #endregion

        static WindIndexer()
        {
            sWindIndexPropertyID = Shader.PropertyToID(name: cWindIndexPropertyName);
        }

        protected void Awake()
        {
            if (_SpriteRenderer != default)
            {
                MaterialPropertyBlock propertyBlock = new MaterialPropertyBlock();

                // If the renderer already has a property block, we need to grab its current values to avoid resetting
                // important information like texture assignment, etc.
                if (_SpriteRenderer.HasPropertyBlock())
                {
                    _SpriteRenderer.GetPropertyBlock(properties: propertyBlock);
                }

                // Randomly pick an index between 0 and the buffer length.
                propertyBlock.SetInt(
                    nameID: sWindIndexPropertyID,
                    value: Random.Range(min: 0, max: WindManager.cBufferLength - 1));

                _SpriteRenderer.SetPropertyBlock(properties: propertyBlock);
            }
        }
    }
}