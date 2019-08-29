//  Copyright © 2019 The nef Authors.

import Bow
import BowEffects

typealias EnvIO<D, E: Error, A> = Kleisli<IOPartial<E>, D, A>
