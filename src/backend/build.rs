fn main() -> Result<(), Box<dyn std::error::Error>> {
    let version = std::fs::read_to_string("../../VERSION")?.trim().to_owned();
    if version.is_empty() {
        return Err("VERSION must not be empty".into());
    }
    println!("cargo:rustc-env=CARNINE_VERSION={version}");
    println!("cargo:rerun-if-changed=../../VERSION");
    tonic_build::compile_protos("../proto/carnine.proto")?;
    Ok(())
}
