fn main() {
    println!("Hello, world!");
    qeval(3);
}

fn qeval(x: i32) -> i32 {
    let y: i32 = x * x * x;

    println!("y: {}", y);
    return x + y + 5;
}
