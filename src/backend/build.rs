fn main() -> Result<(), Box<dyn std::error::Error>> {
    let version = std::fs::read_to_string("../../VERSION")?.trim().to_owned();
    if version.is_empty() {
        return Err("VERSION must not be empty".into());
    }
    println!("cargo:rustc-env=CARNINE_VERSION={version}");
    let build_id = std::env::var("CARNINE_BUILD_ID").unwrap_or_else(|_| version.clone());
    println!("cargo:rustc-env=CARNINE_BUILD_ID={build_id}");
    println!("cargo:rerun-if-changed=../../VERSION");
    println!("cargo:rerun-if-env-changed=CARNINE_BUILD_ID");
    tonic_build::compile_protos("../proto/carnine.proto")?;
    Ok(())
}
