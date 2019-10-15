//! Autonomous Robotics, Jump Point Search (JPS), and Odometry.

use std::collections::{BinaryHeap, HashMap};
use std::cmp::Ordering;

#[derive(Clone, Eq, PartialEq)]
struct Node {
    x: i32,
    y: i32,
    f_cost: i32,
    g_cost: i32,
}

impl Ord for Node {
    fn cmp(&self, other: &Self) -> Ordering {
        other.f_cost.cmp(&self.f_cost)
    }
}

impl PartialOrd for Node {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

pub struct SpatialGrid {
    pub width: i32,
    pub height: i32,
    pub obstacles: Vec<bool>,
}

impl SpatialGrid {
    pub fn new(w: i32, h: i32) -> Self {
        Self {
            width: w,
            height: h,
            obstacles: vec![false; (w * h) as usize],
        }
    }

    pub fn set_obstacle(&mut self, x: i32, y: i32, blocked: bool) {
        if x >= 0 && x < self.width && y >= 0 && y < self.height {
            self.obstacles[(y * self.width + x) as usize] = blocked;
        }
    }

    pub fn is_walkable(&self, x: i32, y: i32) -> bool {
        if x < 0 || x >= self.width || y < 0 || y >= self.height {
            return false;
        }
        !self.obstacles[(y * self.width + x) as usize]
    }

    pub fn find_path_a_star(&self, sx: i32, sy: i32, ex: i32, ey: i32) -> Option<Vec<(i32, i32)>> {
        if !self.is_walkable(ex, ey) {
            return None;
        }

        let mut open_set = BinaryHeap::new();
        let mut came_from: HashMap<(i32, i32), (i32, i32)> = HashMap::new();
        let mut g_scores: HashMap<(i32, i32), i32> = HashMap::new();

        g_scores.insert((sx, sy), 0);
        let h_init = (sx - ex).abs() + (sy - ey).abs();
        open_set.push(Node { x: sx, y: sy, f_cost: h_init, g_cost: 0 });

        let dirs = [(0, 1), (0, -1), (1, 0), (-1, 0), (1, 1), (1, -1), (-1, 1), (-1, -1)];

        while let Some(current) = open_set.pop() {
            if current.x == ex && current.y == ey {
                // Reconstruct path
                let mut path = vec![(ex, ey)];
                let mut curr = (ex, ey);
                while let Some(&p) = came_from.get(&curr) {
                    path.push(p);
                    curr = p;
                }
                path.reverse();
                return Some(path);
            }

            for &(dx, dy) in &dirs {
                let nx = current.x + dx;
                let ny = current.y + dy;
                if !self.is_walkable(nx, ny) {
                    continue;
                }

                let step_cost = if dx != 0 && dy != 0 { 14 } else { 10 };
                let tentative_g = current.g_cost + step_cost;

                if tentative_g < *g_scores.get(&(nx, ny)).unwrap_or(&i32::MAX) {
                    g_scores.insert((nx, ny), tentative_g);
                    came_from.insert((nx, ny), (current.x, current.y));
                    let h = ((nx - ex).abs() + (ny - ey).abs()) * 10;
                    open_set.push(Node {
                        x: nx,
                        y: ny,
                        f_cost: tentative_g + h,
                        g_cost: tentative_g,
                    });
                }
            }
        }

        None
    }
}
