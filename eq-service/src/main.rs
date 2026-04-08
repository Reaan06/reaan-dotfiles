use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{SampleFormat, StreamConfig};
use std::collections::VecDeque;
use std::error::Error;
use std::sync::{Arc, Mutex};

// --- Constantes para el Ecualizador ---
const FFT_SIZE: usize = 1024; // Tamaño de FFT. Obligatorio que sea potencia de 2.
const NUM_BANDS: usize = 5; // Número de bandas

fn main() -> Result<(), Box<dyn Error>> {
    // --- Configuración de Streams de Audio ---
    let host = cpal::default_host();
    let input_device = host
        .default_input_device()
        .expect("No hay dispositivo de entrada disponible");
    let output_device = host
        .default_output_device()
        .expect("No hay dispositivo de salida disponible");

    println!("Dispositivo de entrada: {}", input_device.name()?);
    println!("Dispositivo de salida: {}", output_device.name()?);

    let input_config_supported = input_device.default_input_config()?;
    let output_config_supported = output_device.default_output_config()?;

    let sample_rate = output_config_supported.sample_rate();
    let channels = 2; // Asumimos estéreo

    // 1. Configuración de entrada (Fallback automático si no encuentra F32 ideal)
    let mut best_input_config = input_config_supported.config();
    for cfg in input_device.supported_input_configs()? {
        if cfg.sample_format() == SampleFormat::F32 && cfg.channels() == channels {
            if cfg.max_sample_rate() == sample_rate {
                best_input_config = cfg.with_max_sample_rate().config();
                break;
            }
        }
    }

    // 2. Configuración de salida (Fallback automático)
    let mut best_output_config = output_config_supported.config();
    for cfg in output_device.supported_output_configs()? {
        if cfg.sample_format() == SampleFormat::F32 && cfg.channels() == channels {
            if cfg.max_sample_rate() == sample_rate {
                best_output_config = cfg.with_max_sample_rate().config();
                break;
            }
        }
    }

    // 3. Calculamos la configuración final sin usar métodos .min() o .max() que confunden al compilador
    let final_channels = if best_input_config.channels < best_output_config.channels {
        best_input_config.channels
    } else {
        best_output_config.channels
    };

    let final_sample_rate_val =
        if best_input_config.sample_rate.0 > best_output_config.sample_rate.0 {
            best_input_config.sample_rate.0
        } else {
            best_output_config.sample_rate.0
        };

    let final_stream_config = StreamConfig {
        channels: final_channels,
        sample_rate: cpal::SampleRate(final_sample_rate_val),
        buffer_size: cpal::BufferSize::Default, // 100% compatible
    };

    println!("Usando Configuración de Stream: {:?}", final_stream_config);

    // --- Estado del Procesamiento de Audio ---
    let audio_buffer: Arc<Mutex<VecDeque<f32>>> = Arc::new(Mutex::new(VecDeque::new()));
    let fft_buffer: Arc<Mutex<VecDeque<f32>>> = Arc::new(Mutex::new(VecDeque::new()));

    let buffer_capacity = FFT_SIZE * final_stream_config.channels as usize * 2;
    let fft_frame_capacity = FFT_SIZE * final_stream_config.channels as usize;

    let mut fft_planner = rustfft::FftPlanner::new();
    let fft = fft_planner.plan_fft_forward(FFT_SIZE);
    let ifft = fft_planner.plan_fft_inverse(FFT_SIZE);

    let eq_gains: Arc<Mutex<[f32; NUM_BANDS]>> = Arc::new(Mutex::new([1.5, 0.8, 1.0, 1.2, 1.8]));

    let freq_step = final_stream_config.sample_rate.0 as f32 / FFT_SIZE as f32;
    let eq_band_freqs: Vec<f32> = vec![60.0, 250.0, 1000.0, 4000.0, 16000.0];

    // --- Callback del Stream de Entrada ---
    let input_data_fn = {
        let audio_buffer = Arc::clone(&audio_buffer);
        move |data: &[f32], _: &cpal::InputCallbackInfo| {
            let mut buffer = audio_buffer.lock().unwrap();
            buffer.extend(data.iter().cloned());

            while buffer.len() > buffer_capacity {
                buffer.pop_front();
            }
        }
    };

    // --- Callback del Stream de Salida ---
    let output_data_fn = move |data: &mut [f32], _: &cpal::OutputCallbackInfo| {
        let mut audio_buffer_guard = audio_buffer.lock().unwrap();
        let mut fft_buffer_guard = fft_buffer.lock().unwrap();
        let eq_gains_guard = eq_gains.lock().unwrap();

        while fft_buffer_guard.len() < fft_frame_capacity && !audio_buffer_guard.is_empty() {
            fft_buffer_guard.push_back(audio_buffer_guard.pop_front().unwrap_or(0.0));
        }

        if fft_buffer_guard.len() == fft_frame_capacity {
            let mut time_domain_frame: Vec<f32> = fft_buffer_guard.drain(..).collect();

            if final_stream_config.channels > 1 {
                let mut mono_frame = Vec::with_capacity(FFT_SIZE);
                for i in 0..FFT_SIZE {
                    let mut sum = 0.0;
                    for c in 0..final_stream_config.channels {
                        sum += time_domain_frame
                            [i * (final_stream_config.channels as usize) + (c as usize)];
                    }
                    mono_frame.push(sum / final_stream_config.channels as f32);
                }
                time_domain_frame = mono_frame;
            }

            let mut complex_buffer: Vec<rustfft::num_complex::Complex<f32>> = time_domain_frame
                .into_iter()
                .map(|sample| rustfft::num_complex::Complex::new(sample, 0.0))
                .collect();

            fft.process(&mut complex_buffer);

            for i in 1..FFT_SIZE / 2 {
                let freq = i as f32 * freq_step;
                let mut band_gain = 1.0;

                for band_idx in 0..NUM_BANDS {
                    if freq < eq_band_freqs[band_idx] {
                        band_gain = eq_gains_guard[band_idx];
                        break;
                    }
                }
                if band_gain == 1.0 && NUM_BANDS > 0 {
                    band_gain = eq_gains_guard[NUM_BANDS - 1];
                }

                complex_buffer[i].re *= band_gain;
                complex_buffer[i].im *= band_gain;
            }

            for i in (FFT_SIZE / 2 + 1)..FFT_SIZE {
                complex_buffer[i].re = complex_buffer[FFT_SIZE - i].re;
                complex_buffer[i].im = -complex_buffer[FFT_SIZE - i].im;
            }

            ifft.process(&mut complex_buffer);

            let processed_samples_mono: Vec<f32> = complex_buffer
                .iter()
                .map(|c| c.re / FFT_SIZE as f32)
                .collect();

            let mut processed_frame_stereo: Vec<f32> =
                Vec::with_capacity(FFT_SIZE * final_stream_config.channels as usize);
            for i in 0..FFT_SIZE {
                for _ in 0..final_stream_config.channels {
                    processed_frame_stereo.push(processed_samples_mono[i]);
                }
            }

            let mut samples_written = 0;
            for sample in data.iter_mut() {
                if samples_written < processed_frame_stereo.len() {
                    *sample = processed_frame_stereo[samples_written];
                    samples_written += 1;
                } else {
                    *sample = 0.0;
                }
            }

            if samples_written < data.len() {
                for sample in data.iter_mut().skip(samples_written) {
                    *sample = 0.0;
                }
            }
        } else {
            for sample in data.iter_mut() {
                *sample = 0.0;
            }
        }
    };

    // --- Iniciar Streams ---
    let input_stream = input_device.build_input_stream(
        &final_stream_config,
        input_data_fn,
        |err| eprintln!("Error en stream de entrada: {}", err),
        None,
    )?;

    let output_stream = output_device.build_output_stream(
        &final_stream_config,
        output_data_fn,
        |err| eprintln!("Error en stream de salida: {}", err),
        None,
    )?;

    input_stream.play()?;
    output_stream.play()?;

    println!("Streams de audio iniciados con EQ. Presiona Enter para salir.");

    let stdin = std::io::stdin();
    let mut buf = String::new();
    stdin.read_line(&mut buf)?;

    input_stream.pause()?;
    output_stream.pause()?;

    Ok(())
}
