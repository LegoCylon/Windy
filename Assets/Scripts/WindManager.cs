using UnityEngine;

#pragma warning disable 649 // Silence spurious warnings about private [SerializeField] values never being assigned.
namespace Windy
{
    public class WindManager : MonoBehaviour
    {
        #region Constants

        public const int cBufferLength = 8;

        private const string cBufferVectorArrayPropertyName = "_WindVectorArray";

        #endregion

        #region Fields

        [SerializeField] private float _BufferDecaySeconds;
        [SerializeField] private float _WindDirectionEvaluateSecondsMinimum;
        [SerializeField] private float _WindDirectionEvaluateSecondsMaximum;
        [SerializeField] private float _WindDirectionRotateSecondsMinimum;
        [SerializeField] private float _WindDirectionRotateSecondsMaximum;
        [SerializeField] private WindZone _WindZone;

        private static readonly int sBufferVectorArrayPropertyID;

        private readonly Vector4[] _BufferCurrentArray = new Vector4[cBufferLength];
        private readonly Vector4[] _BufferTargetArray = new Vector4[cBufferLength];
        private float _BufferDecayTimer;
        private float _WindDirectionEvaluateSeconds;
        private float _WindDirectionEvaluateTimer;
        private Quaternion _WindDirectionRotationStart;
        private Quaternion _WindDirectionRotationTarget;
        private float _WindDirectionRotateSeconds;
        private float _WindDirectionRotateTimer;

        #endregion

        static WindManager()
        {
            sBufferVectorArrayPropertyID = Shader.PropertyToID(name: cBufferVectorArrayPropertyName);
        }

        protected void Awake()
        {
            _WindDirectionRotationStart = _WindDirectionRotationTarget = Quaternion.identity;
        }

        protected void Update()
        {
            UpdateWindDirection();
            UpdateBufferArrays();
        }

        private static bool UpdateTimer(float deltaTime, ref float timer, float seconds)
        {
            timer += deltaTime;
            return timer >= seconds;
        }

        private static void StartTimer(ref float seconds, float secondsMinimum, float secondsMaximum) =>
            seconds = (secondsMaximum - secondsMinimum) * Random.value + secondsMinimum;

        private void UpdateWindDirection()
        {
            bool evaluateTimerExpired = UpdateTimer(
                deltaTime: Time.deltaTime,
                timer: ref _WindDirectionEvaluateTimer,
                seconds: _WindDirectionEvaluateSeconds);

            // Wait until it's time to pick a new rotation.
            if (evaluateTimerExpired)
            {
                // Keep the previous target as the new starting rotation and select the new rotation.
                // Note that this assumes a specific rotation around the Y axis favorable to 2D games, so you may need
                // to adjust this for your game's needs.
                _WindDirectionRotationStart = _WindDirectionRotationTarget;
                _WindDirectionRotationTarget = Quaternion.Euler(x: (180f * Random.value) - 180f, y: 90f, z: 0f);

                // Reset the rotation timer and pick a new rotation duration.
                _WindDirectionRotateTimer -= _WindDirectionRotateSeconds;
                StartTimer(
                    seconds: ref _WindDirectionRotateSeconds,
                    secondsMinimum: _WindDirectionRotateSecondsMinimum,
                    secondsMaximum: _WindDirectionRotateSecondsMaximum);

                // Reset the evaluation timer and pick a new evaluation duration (which includes the rotation duration).
                _WindDirectionEvaluateTimer -= _WindDirectionEvaluateSeconds;
                StartTimer(
                    seconds: ref _WindDirectionEvaluateSeconds,
                    secondsMinimum: _WindDirectionEvaluateSecondsMinimum,
                    secondsMaximum: _WindDirectionEvaluateSecondsMaximum);
                _WindDirectionEvaluateSeconds += _WindDirectionRotateSeconds;
            }

            // Wait until the rotation has finished. Note that we stop updating it once the timer has met or passed the
            // requested duration since it would otherwise keep accumulating during the evaluation period.
            bool rotationTimerExpired =
                _WindDirectionRotateTimer >= _WindDirectionRotateSeconds ||
                UpdateTimer(deltaTime: Time.deltaTime,
                    timer: ref _WindDirectionRotateTimer,
                    seconds: _WindDirectionRotateSeconds);

            // If the rotation has expired, then just ensure that the rotation is set to the target.
            if (rotationTimerExpired)
            {
                if (_WindZone != default)
                {
                    _WindZone.transform.rotation = _WindDirectionRotationTarget;
                }
            }
            // Otherwise perform spherical linear interpolation between the start and end rotation based on elapsed
            // time.
            else
            {
                if (_WindZone != default)
                {
                    _WindZone.transform.rotation = Quaternion.Slerp(
                        a: _WindDirectionRotationStart,
                        b: _WindDirectionRotationTarget,
                        t: _WindDirectionRotateTimer / _WindDirectionRotateSeconds);
                }
            }
        }

        private void UpdateBufferArrays()
        {
            // Advance time and calculate how many existing buffers have finished interpolating so we know how many
            // buffer indices to skip.
            int decayCount;
            if (_BufferDecaySeconds > 0f)
            {
                _BufferDecayTimer += Time.deltaTime;
                decayCount = Mathf.FloorToInt(f: _BufferDecayTimer / _BufferDecaySeconds);
                _BufferDecayTimer -= decayCount * _BufferDecaySeconds;
                decayCount = Mathf.Min(a: cBufferLength - 1, b: decayCount);
            }
            else
            {
                decayCount = cBufferLength - 1;
            }

            Vector4 windVector = default;
            if (_WindZone != default)
            {
                Vector3 windDirection = _WindZone.transform.forward;

                // The wind vector is attenuated by the alignment with the horizontal since that's when the wind is most
                // noticeable in a 2D setup, but this can be removed or altered depending on project dimensions &
                // directions.
                float windAttenuation = Vector2.Dot(lhs: windDirection, rhs: Vector2.right);

                // Perform a vector projection of the wind direction onto the right vector to calculate the resulting
                // wind vector.
                // We're just accessing WindZone.windMain here because there's no way to measure the current intensity
                // including pulses & turbulence. If these factors are important, I'd recommend implementing them
                // independently and then modifying windMain with the result.
                windVector = _WindZone.windMain * windAttenuation * Vector2.right;
            }

            // Index N-1: Active simulation.
            _BufferCurrentArray[cBufferLength - 1] = _BufferTargetArray[cBufferLength - 1] = windVector;

            // Index [0, N-1): Previous vector interpolation.
            // This might be a good area to experiment with random timer durations and different types of interpolation.
            if (decayCount > 0)
            {
                for (int bufferIndex = 0; bufferIndex < cBufferLength - 1; ++bufferIndex)
                {
                    _BufferTargetArray[bufferIndex] =
                        bufferIndex + decayCount < cBufferLength
                        ? _BufferTargetArray[bufferIndex + decayCount]
                        : _BufferTargetArray[cBufferLength - 1];
                }
            }

            // Interpolate towards the target vector in the next buffer index based on normalized elapsed time.
            if (_BufferDecaySeconds > 0f)
            {
                for (int bufferIndex = 0; bufferIndex < cBufferLength - 1; ++bufferIndex)
                {
                    _BufferCurrentArray[bufferIndex] = Vector4.Lerp(
                        a: _BufferTargetArray[bufferIndex],
                        b: _BufferTargetArray[bufferIndex + 1],
                        t: _BufferDecayTimer / _BufferDecaySeconds);
                }
            }
            // Otherwise just set all values to the target.
            else
            {
                for (int bufferIndex = 0; bufferIndex < cBufferLength - 1; ++bufferIndex)
                {
                    _BufferCurrentArray[bufferIndex] = _BufferTargetArray[bufferIndex];
                }
            }

            // Update any interested shaders with the new wind vectors.
            Shader.SetGlobalVectorArray(nameID: sBufferVectorArrayPropertyID, values: _BufferCurrentArray);
        }
    }
}