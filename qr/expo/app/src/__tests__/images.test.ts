import { expectedPayload } from '../images'

describe('expectedPayload', () => {
  it('pads the index to three digits, like the generated file names', () => {
    expect(expectedPayload(0)).toBe('https://example.com/benchmark/qr/000')
    expect(expectedPayload(7)).toBe('https://example.com/benchmark/qr/007')
    expect(expectedPayload(499)).toBe('https://example.com/benchmark/qr/499')
  })
})
