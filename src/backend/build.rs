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
    // tonic-build 0.12 printed this for its protos; tonic-prost-build 0.14
    // leaves it to prost-build, which does not. Without it, a changed proto is
    // not compiled again and the build goes on with the old generated code.
    println!("cargo:rerun-if-changed=../proto/carnine.proto");
    tonic_prost_build::compile_protos("../proto/carnine.proto")?;
    Ok(())
}
