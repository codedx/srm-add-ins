package console

import (
	"github.com/codedx/codedx-add-ins/pkg/assert"
	"testing"
)

func TestReadRequiredFlagBaseUrl(t *testing.T) {

	expected := "http://codedx.com"
	actual := ReadRequiredFlagBaseURLValue("name", &expected, 0)

	assert.StringsAreEqual(t, expected, actual.String())
}

func TestReadRequiredFlagBaseUrlWithPath(t *testing.T) {

	expected := "http://codedx.com/codedx"
	actual := ReadRequiredFlagBaseURLValue("name", &expected, 0)

	assert.StringsAreEqual(t, expected, actual.String())
}

func TestReadRequiredFlagBaseUrlWithPort(t *testing.T) {

	expected := "http://codedx.com:8080"
	actual := ReadRequiredFlagBaseURLValue("name", &expected, 0)

	assert.StringsAreEqual(t, expected, actual.String())
}

func TestReadRequiredFlagBaseUrlWithPortAndPath(t *testing.T) {

	expected := "http://codedx.com:8080/codedx"
	actual := ReadRequiredFlagBaseURLValue("name", &expected, 0)

	assert.StringsAreEqual(t, expected, actual.String())
}

func TestReadStringCollectionValueWithSpace(t *testing.T) {

	input := "test; test2"
	actual := ReadStringCollectionValue(&input)

	assert.StringsAreEqual(t, "test", actual[0])
	assert.StringsAreEqual(t, "test2", actual[1])
}

func TestReadStringCollectionValueWithoutSpace(t *testing.T) {

	input := "test;test2"
	actual := ReadStringCollectionValue(&input)

	assert.StringsAreEqual(t, "test", actual[0])
	assert.StringsAreEqual(t, "test2", actual[1])
}

func TestReadStringCollectionValueWithEmptyString(t *testing.T) {

	input := ""
	actual := ReadStringCollectionValue(&input)

	assert.IntsAreEqual(t, 0, len(actual))
}
