//! Dream Maker (DM) Source Code Parser and Preprocessor Validator.
//!
//! Validates DM package environment trees (.dme), preprocessor definitions,
//! datum/atom type hierarchies, proc declarations, and variable scoping.

use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone)]
pub struct DmSourceFile {
    pub path: PathBuf,
    pub lines_of_code: usize,
    pub define_count: usize,
    pub proc_count: usize,
    pub type_count: usize,
}

#[derive(Debug, Default)]
pub struct DmCodebaseStats {
    pub total_files: usize,
    pub total_lines: usize,
    pub total_defines: usize,
    pub total_procs: usize,
    pub total_types: usize,
    pub file_stats: Vec<DmSourceFile>,
    pub defines: HashMap<String, String>,
}

pub struct DmParser {
    root_dir: PathBuf,
}

impl DmParser {
    pub fn new<P: AsRef<Path>>(root: P) -> Self {
        Self {
            root_dir: root.as_ref().to_path_buf(),
        }
    }

    pub fn scan_project(&self) -> Result<usize, String> {
        let stats = self.parse_environment_file("plenum.dme")?;
        Ok(stats.total_files)
    }

    pub fn parse_environment_file(&self, dme_filename: &str) -> Result<DmCodebaseStats, String> {
        let dme_path = self.root_dir.join(dme_filename);
        if !dme_path.exists() {
            return Err(format!("Environment file not found: {}", dme_path.display()));
        }

        let content = fs::read_to_string(&dme_path)
            .map_err(|e| format!("Failed to read {}: {}", dme_path.display(), e))?;

        let mut stats = DmCodebaseStats::default();
        let mut included_files = Vec::new();

        for line in content.lines() {
            let trimmed = line.trim();
            if trimmed.starts_with("#include \"") && trimmed.ends_with('"') {
                let rel_path = &trimmed[10..trimmed.len() - 1];
                included_files.push(rel_path.to_string());
            }
        }

        for rel_file in included_files {
            let full_file_path = self.root_dir.join(&rel_file);
            let file_stat = self.parse_single_dm_file(&full_file_path, &mut stats.defines)?;
            stats.total_lines += file_stat.lines_of_code;
            stats.total_defines += file_stat.define_count;
            stats.total_procs += file_stat.proc_count;
            stats.total_types += file_stat.type_count;
            stats.file_stats.push(file_stat);
        }

        stats.total_files = stats.file_stats.len();
        Ok(stats)
    }

    pub fn parse_single_dm_file(
        &self,
        filepath: &Path,
        defines: &mut HashMap<String, String>,
    ) -> Result<DmSourceFile, String> {
        let content = fs::read_to_string(filepath)
            .map_err(|e| format!("Failed to read DM file {}: {}", filepath.display(), e))?;

        let mut loc = 0;
        let mut define_count = 0;
        let mut proc_count = 0;
        let mut type_count = 0;

        for line in content.lines() {
            let trimmed = line.trim();
            if trimmed.is_empty() || trimmed.starts_with("//") {
                continue;
            }
            loc += 1;

            if trimmed.starts_with("#define ") {
                define_count += 1;
                let parts: Vec<&str> = trimmed[8..].split_whitespace().collect();
                if parts.len() >= 2 {
                    defines.insert(parts[0].to_string(), parts[1].to_string());
                } else if parts.len() == 1 {
                    defines.insert(parts[0].to_string(), "1".to_string());
                }
            } else if trimmed.contains("/proc/") || (trimmed.starts_with("proc/") && trimmed.ends_with(')')) {
                proc_count += 1;
            } else if trimmed.starts_with("/datum/")
                || trimmed.starts_with("/atom/")
                || trimmed.starts_with("/turf/")
                || trimmed.starts_with("/obj/")
                || trimmed.starts_with("/mob/")
                || trimmed.starts_with("/area/")
            {
                type_count += 1;
            }
        }

        Ok(DmSourceFile {
            path: filepath.to_path_buf(),
            lines_of_code: loc,
            define_count,
            proc_count,
            type_count,
        })
    }
}
