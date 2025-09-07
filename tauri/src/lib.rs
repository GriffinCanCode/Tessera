use std::process::{Command, Child, Stdio};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;
use tauri::{Manager, State, Emitter};

// Backend service manager
#[derive(Default)]
pub struct BackendManager {
    processes: Arc<Mutex<Vec<Child>>>,
}

impl BackendManager {
    pub fn new() -> Self {
        Self {
            processes: Arc::new(Mutex::new(Vec::new())),
        }
    }

    pub fn start_services(&self, app_handle: tauri::AppHandle) -> Result<(), Box<dyn std::error::Error>> {
        let processes = Arc::clone(&self.processes);
        
        thread::spawn(move || {
            // Start Python services first
            if let Err(e) = start_python_services(&processes) {
                eprintln!("Failed to start Python services: {}", e);
            }
            
            // Wait a bit for Python services to initialize
            thread::sleep(Duration::from_secs(3));
            
            // Start Perl API server
            if let Err(e) = start_perl_service(&processes) {
                eprintln!("Failed to start Perl service: {}", e);
            }
            
            // Emit ready event to frontend
            thread::sleep(Duration::from_secs(2));
            let _ = app_handle.emit_to("main", "backend-ready", ());
        });
        
        Ok(())
    }

    pub fn stop_services(&self) {
        if let Ok(mut processes) = self.processes.lock() {
            for mut process in processes.drain(..) {
                let _ = process.kill();
                let _ = process.wait();
            }
        }
    }
}

fn start_python_services(processes: &Arc<Mutex<Vec<Child>>>) -> Result<(), Box<dyn std::error::Error>> {
    // Get the project root directory (parent of tauri)
    let project_root = std::env::current_dir()?.parent().unwrap_or(std::path::Path::new(".")).to_path_buf();
    let backend_path = project_root.join("backend").join("python-backend");
    
    // Start embedding service
    let embedding_service = Command::new("./venv/bin/python3")
        .arg("-m")
        .arg("src.services.embedding_service")
        .current_dir(&backend_path)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()?;
    
    // Start Gemini service
    let gemini_service = Command::new("./venv/bin/python3")
        .arg("-m")
        .arg("src.services.gemini_service")
        .current_dir(&backend_path)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()?;
    
    if let Ok(mut procs) = processes.lock() {
        procs.push(embedding_service);
        procs.push(gemini_service);
    }
    
    Ok(())
}

fn start_perl_service(processes: &Arc<Mutex<Vec<Child>>>) -> Result<(), Box<dyn std::error::Error>> {
    // Get the project root directory (parent of tauri)
    let project_root = std::env::current_dir()?.parent().unwrap_or(std::path::Path::new(".")).to_path_buf();
    let backend_path = project_root.join("backend");
    
    let perl_service = Command::new("perl")
        .arg("perl-backend/script/api_server.pl")
        .current_dir(&backend_path)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()?;
    
    if let Ok(mut procs) = processes.lock() {
        procs.push(perl_service);
    }
    
    Ok(())
}

// Tauri commands
#[tauri::command]
async fn start_backend_services(
    backend_manager: State<'_, BackendManager>,
    app_handle: tauri::AppHandle,
) -> Result<String, String> {
    backend_manager
        .start_services(app_handle)
        .map_err(|e| e.to_string())?;
    Ok("Backend services starting...".to_string())
}

#[tauri::command]
async fn stop_backend_services(backend_manager: State<'_, BackendManager>) -> Result<String, String> {
    backend_manager.stop_services();
    Ok("Backend services stopped".to_string())
}

#[tauri::command]
async fn check_service_health() -> Result<String, String> {
    // Simple health check - could be expanded
    Ok("Services running".to_string())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let backend_manager = BackendManager::new();
    
    tauri::Builder::default()
        .manage(backend_manager)
        .invoke_handler(tauri::generate_handler![
            start_backend_services,
            stop_backend_services,
            check_service_health
        ])
        .setup(|app| {
            if cfg!(debug_assertions) {
                app.handle().plugin(
                    tauri_plugin_log::Builder::default()
                        .level(log::LevelFilter::Info)
                        .build(),
                )?;
            }
            
            // Auto-start backend services
            let backend_manager = app.state::<BackendManager>();
            let app_handle = app.handle().clone();
            if let Err(e) = backend_manager.start_services(app_handle) {
                eprintln!("Failed to start backend services: {}", e);
            }
            
            Ok(())
        })
        .on_window_event(|window, event| {
            if let tauri::WindowEvent::CloseRequested { .. } = event {
                // Stop backend services when window closes
                let backend_manager = window.state::<BackendManager>();
                backend_manager.stop_services();
            }
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
